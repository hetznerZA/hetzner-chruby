desc 'Clean all dependencies and artifacts'
task :clean => %w{clean:pkg clean:ruby clean:puppet clean:spec}

namespace :clean do
  desc 'Clean the module build dir'
  task :pkg do
    require 'fileutils'

    printf( '%-60s', 'Removing module build artifacts' )
    FileUtils.rm_rf(File.join(ROOT, 'pkg'))
    puts '...ok'
  end

  desc 'Clean the Ruby dependencies'
  task :ruby do
    require 'fileutils'

    printf( '%-60s', 'Removing gem bundle' )
    FileUtils.rm_rf(File.join(ROOT, '.bundle'))
    FileUtils.rm_rf(File.join(ROOT, 'Gemfile.lock'))
    puts '...ok'
  end

  desc 'Clean the Puppet module dependencies'
  task :puppet do
    require 'fileutils'

    printf( '%-60s', 'Removing module dependencies' )
    FileUtils.rm_rf(File.join(ROOT, 'modules'))
    FileUtils.rm_rf(File.join(ROOT, '.librarian'))
    FileUtils.rm_rf(File.join(ROOT, '.tmp'))
    FileUtils.rm_rf(File.join(ROOT, 'Puppetfile.lock'))
    puts '...ok'
  end

  desc 'Clean the test artifacts'
  task :spec do
    require 'fileutils'

    printf( '%-60s', 'Removing vagrant boxes if any...' )
    FileUtils.rm_rf(File.join(ROOT, '.vagrant'))
    puts '...ok'
  end
end
