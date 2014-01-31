
desc 'Lint files for syntax and style'
task :lint => %w{lint:puppet lint:erb lint:ruby lint:style}

namespace :lint do
  desc 'Lint Ruby Syntax'
  task :ruby do
    require 'open3'

    fail_on_error = ENV['FAIL_ON_ERROR'] == 'true' ? true : false
    ignore_paths  = (ENV['IGNORE_PATHS'] || '').split(' ')
    ignore_paths << 'modules'
    ignore_paths << 'fixtures'

    Dir.chdir ROOT do
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
    end

    puts ''
  end

  desc 'Lint ERB Syntax'
  task :erb do
    require 'open3'

    fail_on_error = ENV['FAIL_ON_ERROR'] == 'true' ? true : false
    ignore_paths  = (ENV['IGNORE_PATHS'] || '').split(' ')
    ignore_paths << 'modules'
    ignore_paths << 'fixtures'

    Dir.chdir ROOT do
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
    end

    puts ''
  end

  desc 'Lint Puppet Syntax'
  task :puppet do
    require 'bundler'
    Bundler.setup
    require 'puppet'

    fail_on_error    = ENV['FAIL_ON_ERROR'] == 'true' ? true : false
    Puppet['parser'] = ENV['PARSER'] || 'future'
    ignore_paths     = (ENV['IGNORE_PATHS'] || '').split(' ')

    Dir.chdir ROOT do
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
    end

    puts ''

    fail if fail_on_error and not errors.empty?
  end

  desc 'Lint Puppet style with puppet-lint'
  task :style do
    require 'pathname'
    require 'bundler'
    Bundler.setup
    require 'puppet-lint'
    begin
      require 'puppet-lint/optparser'
    rescue LoadError
      pre_4 = true
    end

    fail_on_error   = ENV['FAIL_ON_ERROR'] == 'true'   ? true : false
    fail_on_warning = ENV['FAIL_ON_WARNING'] == 'true' ? true : false

    Dir.chdir ROOT do
      PuppetLint::OptParser.build unless pre_4

      ignore_paths    = PuppetLint.configuration.ignore_paths ||
                          (ENV['IGNORE_PATHS'] || '').split(' ')
      ignore_paths << 'modules'

      if ENV['LINT_FORMAT']
        PuppetLint.configuration.log_format = ENV['LINT_FORMAT']
      else
        PuppetLint.configuration.with_filename = true
      end

      (ENV['DISABLE_CHECKS'] || '').split(' ').each do |check|
        PuppetLint.configuration.send( "disable_#{check}" )
      end


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
      end

      fail if fail_on_error && linter.errors?
      fail if fail_on_warning && linter.warnings?
    end
  end
end

namespace :help do
  desc 'Help for linting'
  task :lint do
    pager = ENV['PAGER'] || 'less'
    IO.popen(pager, 'w') {|f| f.puts  LINT_HELP }
  end
end

LINT_HELP = <<LINT_HELP_TEXT


    ## Linting

        Linting saves time by quickly checking for syntax and stylistic
    errors that would otherwise prevent your code from being deployed.


    ## Main task:

        Runs all sub tasks.


    ## Subtasks:

      Common Environment Variables:
      Each subtask below will check both of these environment variables.

      FAIL_ON_ERROR
        If true returns 1 when encountering invalid code, else 0.
        Default is false (check stdout for output)

      IGNORE_PATHS
        A space separated list of paths or path parts.  Files whose paths
        contain the listed paths or path parts will be excluded.  By
        default excludes any files that contain "modules" or "fixtures"
        in their paths. (These are the default locations for librarian-
        puppet and puppetlabs_spec_helper dependencies respectively)


    lint:ruby:
      Use Ruby's syntax checking abilties on all module .rb files.

      Important Environment Variables:

      See "Common Environment Variables" above.


    lint:erb:
      Use Ruby's syntax checking abilties on all module .erb files.

      Important Environment Variables:

      See "Common Environment Variables" above.


    lint:puppet:
      Use Puppet's syntax checking abilties on all module .pp files.

      Important Environment Variables:

      PARSER
        The Puppet parser to use when checking Puppet files.  Default is
        'future', other valid value is 'current'.

      See "Common Environment Variables" above.

    lint:style:
      Use Puppet-Lint's style checking abilties on all module .pp files.

      Important Environment Variables:

      FAIL_ON_ERROR
        If true returns 1 when encountering failing a major check, else 0.
        Default is false (check stdout for output)

      FAIL_ON_WARNING
        If true returns 1 when encountering failing a minor check, else 0.
        Default is false (check stdout for output)

      IGNORE_PATHS
        See "Common Environment Variables" above.

      PARSER
        The Puppet parser to use when checking Puppet files.  Default is
        'future', other valid value is 'current'.

      LINT_FORMAT
        The line format for each check failure. Uses puppet-lint's default.

      DISABLE_CHECKS
        A space separated list of checks to disable.  For example, to
        disable the "hard_tabs"[1] check you would use on the command
        line `--no-hard_tabs-check', or programmatically send
        `disable_hard_tabs' to `PuppetLint.configuration', but using
        this rake task you would call:
          $ DISABLE_CHECKS=hard_tabs rake lint:style

        1. http://puppet-lint.com/checks/hard_tabs/

      DEBUG
        If set to 'true' will output all of puppet-lints configuration
        prior to running.


LINT_HELP_TEXT
