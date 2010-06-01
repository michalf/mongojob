$LOAD_PATH.unshift 'lib'
require 'mongojob/version'

Gem::Specification.new do |s|
  s.name              = "mongojob"
  s.version           = MongoJob::Version
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "MongoJob is a MongoDB-backed queueing system"
  s.homepage          = "http://github.com/michalf/mongojob"
  s.email             = "michalf@openlabs.pl"
  s.authors           = [ "Michal Frackowiak" ]

  s.files             = %w( README.md Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  # s.files            += Dir.glob("man/**/*")
  s.files            += Dir.glob("spec/**/*")
  s.files            += Dir.glob("tasks/**/*")
  s.executables       = [ "mongojob-cli", "mongojob-web", "mongojob-deamon", "mongojob-worker"]

  s.extra_rdoc_files  = [ "LICENSE", "README.md" ]
  s.rdoc_options      = ["--charset=UTF-8"]

  s.add_dependency "mongo_mapper"
  s.add_dependency "eventmachine"
  s.add_dependency "sinatra"
  s.add_dependency "haml"
  s.add_dependency "vegas"

  s.description = <<description
    MongoJob is a MongoDB-backed Ruby library for creating background jobs,
    placing those jobs on multiple queues, and processing them later.
description
end
