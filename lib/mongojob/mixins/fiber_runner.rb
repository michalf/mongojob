module MongoJob
  module Mixins
    module FiberRunner

      module ClassMethods
        def task method_name, period, *args
          @tasks ||= []
          @tasks << {method_name: method_name, period: period, args: args}
        end
      end

      module InstanceMethods
        
        def run_em_fiber period, &blk
          # log.info "Starting tick #{method_name} with period #{period} seconds"
          Fiber.new do
            loop do
              f = Fiber.current
              begin
                # log.debug "Running method #{method_name}"
                blk.call
              rescue Exception => e
                # do something
                # log.error "Caught exception when running #{method_name}"
                # log.error e
                p e
              end
              EM.add_timer period do
                f.resume
              end
              Fiber.yield
            end
          end.resume
        end

        def run_defined_tasks
          tasks = nil
          self.class.class_eval do
            tasks = @tasks || []
          end
          tasks.each do |task|
            run_em_fiber task[:period] do
              self.send task[:method_name], *task[:args]
            end
          end
        end

      end
    end
  end
end