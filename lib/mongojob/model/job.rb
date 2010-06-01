module MongoJob
  module Model
    class Job
      include MongoMapper::Document
      extend MongoJob::Mixins::Document
      
      extend Helpers
      include Helpers
      
      key :queue_name, String
      key :options, Hash
      key :klass, String
      
      key :worker_id, String
      key :status, String, default: 'queued' # one of 'queued', 'working', 'done', 'failed'
      key :error # if failed
      
      key :progress, Hash # :at of :total
      key :custom_status, Hash # Any custom status set by the worker
      key :pinged_at, Time # Should be updated frequently by the worker
      
      key :release_at, Time
      key :started_at, Time
      key :completed_at, Time
      timestamps!
      
      belongs_to :queue, class_name: 'MongoJob::Model::Queue', foreign_key: :queue_name
      belongs_to :worker, class_name: 'MongoJob::Model::Worker', foreign_key: :worker_id
      
      before_create :setup_queue
      before_create :set_release_at
      
      # Make sure the queue exists for a given queue name. The usual way to create a job is to provide a queue_name
      # without caring about the unmet reference, so we need to fix it here.
      def setup_queue
        queue = Queue.find self.queue_name
        unless queue
          queue = Queue.create _id: self.queue_name
        end
      end
      
      def set_release_at
        self.release_at ||= Time.now
      end
      
      def job_class
        @job_class ||= constantize klass
      end
      
      def job_object
        @job_object ||= job_class.new(self)
      end
      
      def fail error
        error_text = error.is_a?(Exception) ? "#{error.message}\n\n#{error.backtrace}" : error.to_s
        self.set({
          status: 'failed',
          error: error_text
        })
        reload
      end
      
      def complete
        set({
          status: 'done',
          completed_at: Time.now
        })
      end
      
      # Usage:
      # at(0.29) - at 29%
      # at(0.29,1.0) - at 29%
      # at(29,100) - at 29%
      # at(2,7) - at 2 of 7
      # at(2,7, {status: {foo: 'bar'}}) - at 2 of 7, and set custom_status
      def at *args
        options = args.last.is_a?(Hash) ? args.pop : {}
        num = args[0]
        total = args[1] || 1.0
        custom_status = options[:status]
        data = { pinged_at: Time.now }
        data[:progress] = {
          at: num,
          total: total
        } if num
        data[:custom_status] = custom_status if custom_status
        set data
        reload
        
        # TODO: stop the job if cancelled, e.g. by raising an exception.
      end
      
      def percent_done
        progress['at'].to_f/ progress['total'].to_f if progress['at']
      end
      
      # Pop the first unassigned job from the queue
      def self.reserve(queue_name, worker_id)
        begin
          job = self.first conditions: {
            queue_name: queue_name,
            status: 'queued'
          }, order: 'release_at'
          return nil unless job
          if job
            # Might be free. Update it with the new status
            self.set({id: job.id, status: 'queued'}, {status: 'working', worker_id: worker_id, started_at: Time.now})
          end
          job.reload
        end while job.worker_id != worker_id
        job
      end
      
      def ping
        set pinged_at: Time.now
        reload
      end
      
    end
  end
end