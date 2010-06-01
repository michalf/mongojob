require 'spec/rake/spectask'

desc "Run the specs under spec"
Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--options', "spec/spec.opts"]
  t.spec_files = FileList['spec/**/*_spec.rb']
end

namespace :spec do 
  desc "Run specs with RCov" 
  Spec::Rake::SpecTask.new('rcov') do |t|
    t.spec_files = FileList['spec/**/*_spec.rb'] 
    t.rcov = true 
    t.rcov_opts = ['--exclude', '\/Library\/Ruby']
  end
end
