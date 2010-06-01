require "sinatra"
require "haml"
require "sass"
require "json"

require "mongojob"

require "mongojob/web/helpers"

module MongoJob
  class Web < Sinatra::Base
    
    helpers Sinatra::Partials
    helpers WebHelpers
    
    configure do
      set :raise_errors, Proc.new { test? }
      set :show_exceptions, Proc.new { development? }
      set :dump_errors, true
      # set :sessions, true
      # set :logging, false #Proc.new { ! test? }
      set :methodoverride, true
      set :static, true
      set :public, MJ_ROOT + '/web/public'
      set :views, MJ_ROOT + '/web/views'
      set :root, MJ_ROOT
      
      # set :logging, false 
      #       LOGGER = Logger.new(::File.join(APP_ROOT, 'log/access.log')) 
      #       use Rack::CommonLogger, LOGGER 
    end
    
    configure :development do
      use Rack::Reloader
    end
    
    before do
      @config = {
        host: MongoJob.host,
        database_name: MongoJob.database_name
      }
    end
    
    get "/style/:style.css" do
      headers 'Content-Type' => 'text/css; charset=utf-8'
      sass :"style/#{params[:style]}"
    end
    
    get "/" do
      @queues = Model::Queue.all
      @workers = Model::Worker.all
      # TODO: Make some overview
      haml :index
    end
    
    # Queue detailed information
    get "/queue/:id" do
      @queue = Model::Queue.find params[:id]
      @jobs = @queue.jobs.all status: (params['job_status'] || 'queued')
      haml :queue
    end
    
    get "/worker/:id" do
      @worker = Model::Worker.find params[:id]
      haml :worker
    end
    
    get "/job/:id" do
      @job = Model::Job.find params[:id]
      haml :job
    end
    
    delete "/job/:id" do
      @job = Model::Job.find params[:id]
      MongoJob.dequeue(@job.id)
    end
    
    
  end
end
