_, ROOT = Rake.application.find_rakefile_location

Dir[ROOT + '/tasks/**/*.rake'].each do |tasks|
  load File.expand_path( tasks )
end

task :default => :help

namespace :ci do

  desc 'Run rspec-puppet formatted for Jenkins'
  task :spec do
    ENV['SPEC_FORMAT'] = '-r yarjuf -f JUnit -o results_spec.xml -fd'
    Rake::Task['spec'].invoke
  end

  desc 'Lint Puppet style with puppet-lint formatted for Jenkins'
  task :lint do
    ENV['LINT_FORMAT'] = '%{path}:%{linenumber}:%{check}:%{KIND}:%{message}'
    Rake::Task['lint'].invoke
  end

end

