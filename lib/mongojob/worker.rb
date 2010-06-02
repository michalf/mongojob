require "eventmachine"
require "fiber"
require "optparse"

module MongoJob
  
  module ProcessWatcher
    def process_exited
      put 'the forked child died!'
    end
  end

  
  class Worker
    
    extend Mixins::FiberRunner::ClassMethods
    include Mixins::FiberRunner::InstanceMethods
    
    extend Helpers
    include Helpers
    
    task :tick, 3
    task :work_job, 1
    task :monitor_jobs, 3


    attr_accessor :current_jobs
    attr_accessor :log
    
    def self.default_options
      @default_options ||= {
        max_jobs: 1,
        log: STDOUT,
        loglevel: Logger::DEBUG
      }
    end

    # Workers should be initialized with an array of string queue
    # names. The order is important: a Worker will check the first
    # queue given for a job. If none is found, it will check the
    # second queue name given. If a job is found, it will be
    # processed. Upon completion, the Worker will again check the
    # first queue given, and so forth. In this way the queue list
    # passed to a Worker on startup defines the priorities of queues.
    #
    # If passed a single "*", this Worker will operate on all queues
    # in alphabetical order. Queues can be dynamically added or
    # removed without needing to restart workers using this method.
    def initialize(*queues)
      options = {}
      options = queues.pop if queues.last.is_a?(Hash)
      options = self.class.default_options.merge(options)
      queues = options[:queues] if (queues.nil? || queues.empty?)
      raise "No queues provided" if (queues.nil? || queues.empty?)
      @id = options[:id]
      @queues = queues
      @max_jobs = options[:max_jobs]
      @current_jobs = []
      @job_pids = {}
      
      # Initialize logger
      @log = ::Logger.new options[:log]
      @log.formatter = Logger::Formatter.new
      @log.level = options[:loglevel]
      $log = log
    end
    
    # chomp'd hostname of this machine
    def hostname
      @hostname ||= `hostname`.strip
    end
    
    def id
      @id ||= "#{hostname}:#{Process.pid}"
    end
    
    # Runs the worker
    def run
      log.info "Starting worker"
      register_signal_handlers
      EM.run do
        run_defined_tasks
      end
    end
    
    # Contains the working cycle:
    # 0. Maintanance stuff
    # 1. Get a job
    # 2. Run a job
    def work_job
      
      # MAINTENANCE
      
      # Are we shutting down?
      if @shutdown
        Kernel.exit!(0) if @current_jobs.size == 0
      end
      
      # PROCESSING JOBS
      
      # Get a job
      job = get_new_job
      return unless job
      log.info "Got a new job #{job.id}"
      
      if job.job_class.fork?
        # Job that requires a fork, perfect for long-running stuff.
        log.debug "Forking the process for job #{job.id}"
        pid = fork do
          process_job job
        end
        @job_pids[job.id] = pid
        # TODO: We need to store which PID corresponds to this job
      elsif job.job_class.fiber?
        # A job that requires a separate fiber.
        log.debug "Creating a new fiber for job #{job.id}"
        Fiber.new do
          process_job job
          finish_job job
        end.resume
      else
        # Old-school, blocking job
        log.debug "Running job #{job.id} in the blocking mode"
        process_job job
        finish_job job
      end
    end
    
    def get_new_job
      return if @current_jobs.size >= @max_jobs
      job = nil
      @queues.find do |queue|
        job = MongoJob.reserve(queue, self.id)
      end
      @current_jobs << job.id if job
      job
    end
    
    # Processes the job, in the child process if forking.
    def process_job job
      begin
        log.info "Performing job #{job.id}"
        jo = job.job_object
        jo.log = log
        jo.perform
        log.info "Job #{job.id} completed"
        job.complete
        Model::Worker.increment(id, {:'stats.done' => 1})
      rescue Exception => e
        log.info "Job #{job.id} failed"
        log.info e
        job.fail e
        Model::Worker.increment(id, {:'stats.failed' => 1})
        p e
      end
    end
    
    # Removes job from the internal stack
    def finish_job job
      job_id = job.respond_to?(:id) ? job.id : job
      @current_jobs.delete job_id
      @job_pids.delete(job_id)
    end
    
    # Mark job as failed
    def fail_job job, error
      job.fail error
    end
    
    # Forks a process and runs the code passed in the block in the new process
    def fork &blk
      pid = Process.fork do
        if EM.reactor_running?
          # Need to clear EM reactor
          EM.stop_event_loop
          EM.release_machine
          EM.instance_variable_set( '@reactor_running', false )
        end
        # TODO: Should we rescue exceptions from the block call?
        blk.call
        Process.exit!(0)
      end
      # Detach the process. We are not using Process.wait.
#      Process.detach pid
      pid
    end
    
    # Monitors jobs and pings storage if they are alive.
    # Currently it monitors only forked processes
    def monitor_jobs
      @job_pids.each do |job_id, pid|
        # Check if alive
        line = `ps -www -o rss,state -p #{pid}`.split("\n")[1]
        rss = state = nil
        running = true
        if line
          rss, state = line.split ' '
          log.debug "Process #{pid} for job #{job_id} in state #{state}, uses #{rss}k mem"
        else
          # Missing process, which means something went very wrong.
          # TODO: report it!
          log.debug "Process #{pid} for job #{job_id} is missing!"
          running = false
        end
        
        # Now check if finished, which means it will be in Z (zombie) status
        # TODO: should we use EventMachine#watch_process ?
        if state =~ /Z/
          # Process completed, collect information
          pid, status = Process.wait2 pid
          log.debug "Process #{pid} for job #{job_id} exited with status #{status.exitstatus}"
          running = false
        end
        
        job = MongoJob.find_job job_id
        
        if running
          # Still running, so ping database
          # One more thing to check - if the job does not exist, we are killing the process.
          if job
            job.ping
          else
            log.info "Job #{job_id} for process #{pid} is missing, killing"
            Process.kill 'KILL', pid
          end
        else
          # Process not running
          # Check the status of the job - if it is still marked as "working", we should set its
          # status to "failed"
          if job && job.status == 'working'
            job.fail "Process missing."
          end
          # For sure we are not working on it anymore, so remove from the stack
          finish_job job_id
        end
        
      end
    end
    
    # Periodically send pings so that we know that the worker is alive.
    # The method also checks stored worker status and shuts down the worker
    # if the stored status indicates failure or timeout.
    def tick
      worker = Model::Worker.find id
      
      # Shut down if there is no worker status stored
      # shutdown! unless worker
      
      # Shut down if worker status is different than 'ok'
      # shutdown! unless worker.status == 'ok'
      
      data = tick_data.merge({
        pinged_at: Time.now,
        status: 'ok',
        queues: @queues
      })
     Model::Worker.tick id, data
    end
    
    # Prepares data to be send alongside with the tick.
    def tick_data
      {
        hostname: hostname,
        ip: real_ip,
        custom_status: custom_status
      }
    end
    
    # Override this method if needed.
    def custom_status
      {}
    end
    
    # Retrieves the real IP address of the machine
    def real_ip
      return @real_ip if @real_ip
      begin
        orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily

        UDPSocket.open do |s|
          s.connect '64.233.187.99', 1
          @real_ip = s.addr.last
        end
      ensure
        Socket.do_not_reverse_lookup = orig
      end
      @real_ip
    end
    
    # Registers the various signal handlers a worker responds to.
    #
    # TERM: Shutdown immediately, stop processing jobs.
    #  INT: Shutdown immediately, stop processing jobs.
    # QUIT: Shutdown after the current job has finished processing.
    def register_signal_handlers
      trap('TERM') { shutdown!  }
      trap('INT')  { shutdown!  }

      trap('QUIT') { shutdown   }

      log.info "Registered signals"
    end

    # Schedule this worker for shutdown. Will finish processing the
    # current jobs.
    def shutdown
      log.info 'Shutting down...'
      @shutdown = true
    end

    # Kill the child and shutdown immediately.
    def shutdown!
      shutdown
      kill_jobs
    end
    
    # Kills all jobs
    def kill_jobs
      log.debug "Immediately killing all jobs"
      @job_pids.each do |job_id, pid|
        log.debug "Killing process #{pid} with job #{job_id}"
        Process.kill 'KILL', pid
      end
      
      # How to kill fiber jobs? Remove them from @current_jobs, mark as failed
      fiber_jobs = @current_jobs.select{|job_id| ! @job_pids[job_id]}
      fiber_jobs.each do |job_id|
        # FAIL FAIL FAIL!!!
        job = MongoJob.find_job job_id
        if job
          job.fail "Process killed."
        end
        finish_job job_id
      end
    end

    # Parse command-line parameters
    def self.parse_options
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: #{::File.basename($0)} [options]"
        opts.on('-q QUEUES', 'coma-separated queues this worker will handle') {|queues|
          options[:queues] = queues.split(/,\s*/)
        }
        opts.on('-h HOST', "--host HOST", "set the MongoDB host") {|host|
          MongoJob.host = host
        }
        opts.on('-d DATABASE_NAME', "--database-name DATABASE_NAME", "set the MongoDB database name") {|database_name|
          MongoJob.database_name = database_name
        }
        opts.on("-l LOGFILE", "logfile, or STDOUT to log to console") do |v|
          options[:log] = (v == 'STDOUT' ? STDOUT : v) 
        end
        opts.on("-v LOGLEVEL", "one of DEBUG, INFO, WARN, ERROR, FATAL") do |v|
          options[:loglevel] = v
        end
        opts.on("-r LOAD_MODULE", "requires an extra ruby file") do |v|
          require v
        end
        opts.on("-i ID", "set worker id") do |v|
          options[:id] = v
        end
        opts.on("-m MAX_JOBS", "max jobs ") do |v|
          options[:max_jobs] = v.to_i
        end
      end.parse!
      options
    end

  end
end