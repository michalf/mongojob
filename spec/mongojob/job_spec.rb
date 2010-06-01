require File.join(File.dirname(__FILE__), '../spec_helper.rb')

describe "MongoJob" do
  describe "Job" do
    
    it "should properly set self.@threading value" do
      class ForkJob < MongoJob::Job
        threading :fork
      end
      
      class FiberJob < MongoJob::Job
        threading :fiber
      end
      
      class NonForkJob < MongoJob::Job
        threading false
      end
      
      ForkJob.fork?.should == true
      ForkJob.fiber?.should == false
      FiberJob.fork?.should == false
      FiberJob.fiber?.should == true
      NonForkJob.fork?.should == false
      NonForkJob.fiber?.should == false
    end
    
    it "should run a job" do
      
    end
    
  end
end