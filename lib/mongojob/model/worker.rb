module MongoJob
  module Model
    class Worker
      include MongoMapper::Document
      extend MongoJob::Mixins::Document
      
      key :_id, String # usually of format ip_address:pid
      key :hostname, String
      key :ip, String

      key :queues, Array
      key :status, String
      
      key :custom_status
      
      key :pinged_at
      
      # Can contain keys: done, failed with number of jobs
      key :stats, Hash
      
      timestamps!
      
      many :jobs, class_name: 'MongoJob::Model::Job', foreign_key: :worker_id
      
      def self.tick id, data
        model_worker = Model::Worker.find id
        model_worker ||= Model::Worker.create({
          id: id
          })
        model_worker.set data.merge({ pinged_at: Time.now })
      end
      
    end
  end
end