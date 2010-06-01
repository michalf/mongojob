require File.join(File.dirname(__FILE__), '../spec_helper.rb')

describe "MongoJob" do
  describe "Worker" do
    it "should have a unique id" do
      worker = MongoJob::Worker.new(:queue)
      worker.id.should =~ /^[a-z0-9\-_\.]+:[0-9]+$/i
    end
    
    it "should fetch new jobs" do
      worker = MongoJob::Worker.new(:queue)
      fooworker = MongoJob::Worker.new(:fooqueue)
      MongoJob.enqueue(FooProcessor, {a: 1, b:2})
      

      job = worker.get_new_job
      job.should == nil
      
      job = fooworker.get_new_job
      job.options['a'].should == 1
    end
    
    it "should fetch new jobs in order of its defined queues" do
      worker = MongoJob::Worker.new(:fooqueue, :barqueue, max_jobs: 4)
      MongoJob.enqueue(FooProcessor, {a: 1})
      MongoJob.enqueue(BarProcessor, {a: 2})
      MongoJob.enqueue(FooProcessor, {a: 3})
      MongoJob.enqueue(BarProcessor, {a: 4})

      1.upto(4) do |i|
        job = worker.get_new_job
        job.queue_name.should == 'fooqueue' if i <= 2
        job.queue_name.should == 'barqueue' if i > 2
      end
    end
    
    it "should tick with its worker data" do
      worker = MongoJob::Worker.new(:fooqueue)
      worker.tick
      
      # Database should have a record with the tick data
      MongoJob::Model::Worker.all.should have(1).worker
      worker1 = MongoJob::Model::Worker.all.first
      worker1.id.should == worker.id
    end
    
    it "should run fibers when told so" do
      worker = MongoJob::Worker.new(:fooqueue)
      counter = 0
      EM.run do
        EM.add_timer(5){EM.stop} # stop after 5 seconds
        worker.run_em_fiber(1) do 
          counter += 1
        end
      end
      counter.should >= 4
    end
    
    it "should run defined jobs without errors" do
      EM.run do
        EM.add_timer(5){EM.stop} # stop after 5 seconds
        worker = MongoJob::Worker.new(:fooqueue)
        worker.run_defined_tasks
      end
    end
    
    it "should fork" do
      worker = MongoJob::Worker.new(:fooqueue)
      worker.fork do
        puts "anything"
      end
    end
    
    it "should actully run a job" do
      # real_job = RealJob.new({'file_name' => 'test_file'})
      #       real_job.perform
      #       content = ''
      #       ::File.open(::File.join(TEST_DIR, 'test_file'), 'r') do |f|
      #         content = f.read
      #       end
      #       content.should == 'this actually worked'
      #       ::File.unlink(::File.join(TEST_DIR, 'test_file'))
      
      worker = MongoJob::Worker.new(:realjob)
      MongoJob.enqueue(RealJob)
      pid = Process.fork do
        worker.run
      end
      sleep 3
      Process.kill "KILL", pid
      content = ''
      ::File.open(::File.join(TEST_DIR, 'test_file'), 'r') do |f|
        content = f.read
      end
      content.should == 'this actually worked'
      
      # Wow, at this point we have a nice working job processor!
    end
    
  end
end
