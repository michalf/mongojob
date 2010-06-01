module MongoJob
  # You should extend this class to handle jobs
  class Job
    
    attr_accessor :log
    
    def self.threading threading
      @threading = threading
    end
    def self.fork?
      @threading == :fork
    end
    def self.fiber?
      @threading == :fiber
    end
    
    def self.queue(queue = nil)
      @queue ||= queue
    end
    
    def initialize(job_object, logger = nil)
      @job = job_object
      @log = logger || Logger.new(STDOUT)
    end
    
    def options
      @job.options
    end
    
    def id
      @job.id
    end
    
    # Please implement this method to perform any actual work.
    def perform
      
    end
    
    # Convenience methods
    
    # Set the status of the job for the current itteration. <tt>num</tt> and 
    # <tt>total</tt> are passed to the status as well as any messages. 
    #
    # Usage:
    # at(0.29) - at 29%
    # at(0.29,1.0) - at 29%
    # at(29,100) - at 29%
    # at(2,7) - at 2 of 7
    # at(2,7, {status: {foo: 'bar'}}) - at 2 of 7, and set custom_status
    def at *args
      @job.at *args
    end
    
    # Set custom status for the job. Accepts a hash as a parameter.
    def update_status status
      @job.set({
        custom_status: status,
        pinged_at: Time.now
      })
    end
    
  end
end