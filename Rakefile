task :default => :help

desc 'Install all dependencies locally'
task :deps => %w{deps:ruby deps:puppet}

namespace :deps do
  desc 'Install Ruby gem dependencies'
  task :ruby do
    puts ''
    puts 'Installing Ruby gem dependencies'
    system( 'bundle install' )
  end

  desc 'Install Puppet module dependencies'
  task :puppet do
    puts ''
    puts 'Installing Puppet module dependencies'
    system( 'bundle exec librarian-puppet install' )

    root = Dir.pwd
    puts 'root: '+root
    base = File.basename(root)
    puts 'base: '+base
    parts = base.split('-', 2)
    puts 'parts:'
    puts parts
    mod_name = parts.pop
    puts 'mod_name: '+mod_name
    File.symlink(root, "modules/#{mod_name}")

  end
end

desc 'Print this help message'
task :help do
  system 'rake -T'
end

desc 'Build a packaged Puppet Module in pkg/'
task :build do
  require 'puppet/face'

  pmod = Puppet::Face['module', :current]
  pmod.build('./')
end

desc 'Clean all dependencies and artifacts'
task :clean => %w{clean:pkg clean:ruby clean:puppet}

namespace :clean do
  desc 'Clean the module build dir'
  task :pkg do
    require 'fileutils'

    printf( '%-60s', 'Removing module build artifacts' )
    FileUtils.rm_rf('pkg')
    puts '...ok'
  end

  desc 'Clean the Ruby dependencies'
  task :ruby do
    require 'fileutils'

    printf( '%-60s', 'Removing gem bundle' )
    FileUtils.rm_rf('.bundle')
    puts '...ok'
  end

  desc 'Clean the Puppet module dependencies'
  task :puppet do
    require 'fileutils'

    printf( '%-60s', 'Removing module dependencies' )
    FileUtils.rm_rf('modules')
    puts '...ok'
  end
end

namespace :module do

  desc 'Bump module version to the next minor'
  task :bump do
    require 'puppet_blacksmith'

    m = Blacksmith::Modulefile.new
    v = m.bump!
    puts "Bumping version from #{m.version} to #{v}"
  end

  desc 'Git tag with the current module version'
  task :tag do
    require 'puppet_blacksmith'

    m = Blacksmith::Modulefile.new
    Blacksmith::Git.new.tag!(m.version)
  end

  desc 'Bump version and git commit'
  task :bump_commit => :bump do
    require 'puppet_blacksmith'

    Blacksmith::Git.new.commit_modulefile!
  end

  desc 'Push module to the Puppet Forge'
  task :push => :buid do
    require 'puppet_blacksmith'

    m = Blacksmith::Modulefile.new
    forge = Blacksmith::Forge.new
    puts "Uploading to Puppet Forge #{forge.username}/#{m.name}"
    forge.push!(m.name)
  end

  desc 'Release the Puppet module, doing a ' +
       'clean, build, tag, push, bump_commit and git push.'
  task :release => %w{clean build module:tag
                      module:push module:bump_commit} do

    require 'puppet_blacksmith'

    puts 'Pushing to remote git repo'
    Blacksmith::Git.new.push!
  end
end

namespace :ci do

  desc 'Run rspec-puppet formatted for Jenkins'
  task :spec do
    rspec = 'bundle exec rspec '
    pattern_opts = '-P "spec/{classes,defines,unit,functions,hosts,integration}/**/*_spec.rb" '
    format_opts  = '-r yarjuf -f JUnit -o results_spec.xml '
    sh( rspec + pattern_opts + format_opts )
  end

  namespace :syntax do
    desc 'Check Ruby Syntax'
    task :ruby do
      require 'open3'

      fail_on_error = ENV['FAIL_ON_ERROR'] == 'true' ? true : false
      ignore_paths  = (ENV['IGNORE_PATHS'] || '').split(' ')
      ignore_paths << 'modules'
      ignore_paths << 'fixtures'

      all_paths = Dir.glob('**/*.rb')
      matched_paths = all_paths.reject do |f|
        ignore_paths.any? {|p| f.include?(p)}
      end

      matched_paths.each do |path|
        printf "%-60s", path
        stdin, stdout, stderr, t = Open3.popen3( "ruby -c #{path}")

        if stdout.read =~ /Syntax OK/
          puts '...ok'
        else
          meaningful_lines = stderr.read.lines.to_a[0..1]
          pretty = meaningful_lines.map {|l| "\t" + l.chomp }
          puts "\n" + pretty.join("\n")
        end

        [ stdin, stdout, stderr ].each {|fd| fd.close }
      end

      puts ''
    end

    desc 'Check ERB Syntax'
    task :erb do
      require 'open3'

      fail_on_error = ENV['FAIL_ON_ERROR'] == 'true' ? true : false
      ignore_paths  = (ENV['IGNORE_PATHS'] || '').split(' ')
      ignore_paths << 'modules'
      ignore_paths << 'fixtures'

      all_paths = Dir.glob('**/*.erb')
      matched_paths = all_paths.reject do |f|
        ignore_paths.any? {|p| f.include?(p)}
      end

      matched_paths.each do |path|
        printf "%-60s", path
        stdin, stdout, stderr, t = Open3.popen3(
          "erb -x -T- #{path} | ruby -c"
        )

        if stdout.read =~ /Syntax OK/
          puts '...ok'
        else
          meaningful_lines = stderr.read.lines.to_a[0..1]
          pretty = meaningful_lines.map {|l| "\t" + l.chomp }
          puts "\n" + pretty.join("\n")
        end

        [ stdin, stdout, stderr ].each {|fd| fd.close }
      end

      puts ''
    end

    desc 'Check Puppet Syntax'
    task :puppet do
      require 'puppet'

      fail_on_error    = ENV['FAIL_ON_ERROR'] == 'true' ? true : false
      Puppet['parser'] = ENV['PARSER'] || 'future'
      ignore_paths     = (ENV['IGNORE_PATHS'] || '').split(' ')

      all_paths = Dir.glob('**/*.pp')
      matched_paths = all_paths.reject do |f|
        ignore_paths.any? {|p| f.include?(p)}
      end

      matched_paths.each do |path|
        begin
          printf "%-60s", path

          Puppet[:manifest] = path
          env = Puppet[:environment]
          Puppet::Node::Environment.new(env).known_resource_types.clear
          puts "...ok"
        rescue => detail
          puts "\n\t" + detail.to_s
        end
      end

      puts ''

      fail if fail_on_error and not errors.empty?
    end
  end

  desc 'Run puppet-lint formatted for Jenkins'
  task :lint do
    require 'pathname'
    require 'puppet-lint'
    begin
      require 'puppet-lint/optparser'
    rescue LoadError
      pre_4 = true
    end

    fail_on_error   = ENV['FAIL_ON_ERROR'] == 'true'   ? true : false
    fail_on_warning = ENV['FAIL_ON_WARNING'] == 'true' ? true : false
    ignore_paths    = PuppetLint.configuration.ignore_paths ||
                        (ENV['IGNORE_PATHS'] || '').split(' ')

    PuppetLint.configuration.log_format =
              '%{path}:%{linenumber}:%{check}:%{KIND}:%{message}'

    (ENV['DISABLE_CHECKS'] || '').split(' ').each do |check|
      PuppetLint.configuration.send( "disable_#{check}" )
    end

    PuppetLint::OptParser.build unless pre_4

    if ENV['DEBUG'] == true
      puts 'PuppetLint configuration:'
      PuppetLint.configuration.settings.each_pair do |config, value|
        puts "    #{config} = #{value}"
      end
    end

    RakeFileUtils.send(:verbose, true) do
      linter = PuppetLint.new

      puppet_files = Pathname.glob('**/*.pp')
      matched_files = puppet_files.reject do |f|
        ignore_paths.any? {|p| f.realpath.to_s.include?(p)}
      end

      matched_files.each do |puppet_file|
        linter.file = puppet_file.to_s
        linter.run
        linter.print_problems unless pre_4
      end

      fail if fail_on_error && linter.errors?
      fail if fail_on_warning && linter.warnings?
    end
  end
end
