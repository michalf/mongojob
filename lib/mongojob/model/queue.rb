module MongoJob
  module Model
    class Queue
      include MongoMapper::Document
      extend MongoJob::Mixins::Document
      
      
      key :_id, String # name of the queue
      
      timestamps!
      
      many :jobs, foreign_key: 'queue_name', class_name: 'MongoJob::Model::Job'
        
    end
  end
end