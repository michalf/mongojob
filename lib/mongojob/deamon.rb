module MongoJob
  class Deamon
    
    extend Mixins::FiberRunner::ClassMethods
    include Mixins::FiberRunner::InstanceMethods
    
    
    
    # Runs the worker
    def run
      EM.run do
        run_defined_tasks
      end
    end
    
  end
end