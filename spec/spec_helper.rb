require "spec"
$:.unshift(File.dirname(__FILE__) + '/../lib')
ENV["RACK_ENV"] = ENV["ENVIRONMENT"] = "test"

require "mongojob"

class FooProcessor < MongoJob::Job
  queue :fooqueue
  def perform
    
  end
end

class BarProcessor < MongoJob::Job
  queue :barqueue
  
  def perform
  end
end

class RealJob < MongoJob::Job
  queue :realjob
  threading :fiber
  
  def perform
    ::File.open(::File.join(TEST_DIR, 'test_file'), 'w') do |f|
      f.write "this actually worked"
    end
  end
end

Spec::Runner.configure do |config|
  config.before(:all) do
    ::TEST_DIR = File.expand_path(File.dirname(__FILE__) + '/../tmp/test') unless defined? TEST_DIR
    FileUtils::mkdir_p TEST_DIR
    
    MongoJob.database_name = 'mongojob-test'
  end
  config.before(:each) do
    FileUtils::rm_r Dir["#{TEST_DIR}/*"]
    
    # Remove collections
    MongoJob::Model::Queue.collection.remove
    MongoJob::Model::Job.collection.remove
    MongoJob::Model::Worker.collection.remove
  end
end
