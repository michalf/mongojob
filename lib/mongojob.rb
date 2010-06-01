require "mongo_mapper"

$: << File.dirname(__FILE__)
MJ_ROOT = File.expand_path(File.join(File.dirname(__FILE__),'..'))

require "mongojob/helpers"
require "mongojob/version"
require "mongojob/mixins/document"
require "mongojob/mixins/fiber_runner"
require "mongojob/worker"
require "mongojob/deamon"
require "mongojob/job"

module MongoJob
  
  def self.host=(host)
    @host = host
  end
  
  def self.host
    @host || 'localhost'
  end
  
  def self.connection
    split = host.split ':'
    @connection ||= Mongo::Connection.new(split[0], (split[1] || 27017).to_i)
  end
  
  def self.database_name=(database_name)
    @database_name = database_name
  end
  
  def self.database_name
    @database_name
  end
  
  def self.enqueue(klass, options = {})
    queue_name = klass.is_a?(Class) ? queue_from_class(klass) : klass.to_s
    raise "Given class does not return any queue name" unless queue_name
    job = Model::Job.create({
      klass: klass.is_a?(Class) ? klass.to_s : nil,
      options: options,
      queue_name: queue_name
    })
    job.id.to_s
  end
  
  def self.reserve(queue_name, worker_id)
    Model::Job.reserve(queue_name, worker_id)
  end
  
  def self.find_job(job_id)
    Model::Job.find job_id
  end
  
  def self.dequeue(job_id)
    Model::Job.delete(job_id)
  end
  
  # Given a class, try to extrapolate an appropriate queue based on a
  # class instance variable or `queue` method.
  def self.queue_from_class(klass)
    klass.instance_variable_get(:@queue) ||
      (klass.respond_to?(:queue) and klass.queue)
  end
  
end

Dir[::File.join(::File.dirname(__FILE__), 'mongojob/model/*.rb')].each { |model| require(model) }