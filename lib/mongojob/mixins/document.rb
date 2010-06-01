module MongoJob
  module Mixins
    module Document
      def connection
        MongoJob.connection
      end
      
      def database_name
        MongoJob.database_name
      end
    end
  end
end