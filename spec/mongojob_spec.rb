require File.join(File.dirname(__FILE__), '/spec_helper.rb')


describe "MongoJob" do
  it "should put jobs on the queue" do
    
    MongoJob.enqueue(FooProcessor, {a: 1, b:2})
    
    MongoJob::Model::Job.all.size.should == 1
    MongoJob::Model::Queue.all.size.should == 1
  end
  
  it "should reserve jobs from the queue" do
    MongoJob.enqueue(FooProcessor, {a: 1, b:2})
    worker_id = 'my_worker_id'
    job = MongoJob.reserve(:fooqueue, worker_id)
    job.klass.should == 'FooProcessor'
    job.options['a'].should == 1
    job.options['b'].should == 2
    job.queue_name.should == 'fooqueue'
  end
  
  it "should find jobs by job_id" do
    job_id = MongoJob.enqueue FooProcessor
    job = MongoJob.find_job job_id
    job.should_not == nil
    job.id.to_s.should == job_id
  end
  
  it "should put and get jobs in FIFO order" do
    MongoJob.enqueue(FooProcessor, {a: 0}); sleep 1
    MongoJob.enqueue(FooProcessor, {a: 1}); sleep 1
    MongoJob.enqueue(FooProcessor, {a: 2}); sleep 1
    MongoJob.enqueue(FooProcessor, {a: 3}); sleep 1
    MongoJob.enqueue(FooProcessor, {a: 4}); sleep 1
    
    worker_id = 'my_worker_id'
    0.upto(4).each do |i| 
      job = MongoJob.reserve(:fooqueue, worker_id)
      job.options['a'].should == i
    end      
  end
  
  it "should remove jobs from the queue" do
    job_id = MongoJob.enqueue(FooProcessor, {a: 2})
    MongoJob.dequeue(job_id)
    MongoJob::Model::Job.all.size.should == 0
  end
  
  it "should extract queue name from worker class" do
    
    MongoJob.queue_from_class(FooProcessor).should == :fooqueue
    MongoJob.queue_from_class(BarProcessor).should == :barqueue
        
  end
  
  
end