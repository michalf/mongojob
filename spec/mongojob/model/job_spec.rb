require File.join(File.dirname(__FILE__), '../../spec_helper.rb')

class FakeJob < MongoJob::Job
  
  def perform
    puts "hello"
  end
end

describe "MongoJob" do
  describe "Model" do
    describe "Job" do
   
      it "should properly create job objects" do
        job = MongoJob::Model::Job.create({
          klass: 'FakeJob',
          options: {a: 1}
        })
        job.klass.should == 'FakeJob'
        job.job_class.to_s.should == 'FakeJob'
        job.job_object.class.to_s.should == 'FakeJob'
      end
      
      describe '#at' do
        it "should set percentage progress with at(percent)" do
          job_id = MongoJob.enqueue FooProcessor
          job = MongoJob.find_job job_id
          job.at 0.24
          job = MongoJob.find_job job_id
          job.percent_done.should == 0.24
        end
        
        it "should set percentage progress with at(at, total)" do
          job_id = MongoJob.enqueue FooProcessor
          job = MongoJob.find_job job_id
          job.at 24, 100
          job = MongoJob.find_job job_id
          job.percent_done.should == 0.24
        end
        
        it "should set custom progress and status" do
          job_id = MongoJob.enqueue FooProcessor
          job = MongoJob.find_job job_id
          job.at 24, 100, status: {foo: 'bar'}
          job = MongoJob.find_job job_id
          job.custom_status['foo'].should == 'bar'
        end
        
        it "should set custom progress without status" do
          job_id = MongoJob.enqueue FooProcessor
          job = MongoJob.find_job job_id
          job.at status: {foo: 'bar'}
          job = MongoJob.find_job job_id
          job.custom_status['foo'].should == 'bar'
        end
        
      end
      
    end
  end
end