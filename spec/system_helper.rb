require 'beaker'

module Beaker
  module RSpec
    module Bridge
      def hosts
        @hosts ||= Beaker::RSpec::TestState.instance.hosts.dup
      end

      def options
        @options ||= Beaker::RSpec::TestState.instance.options.dup
      end

      def logger
        @logger ||= options[:logger]
      end
    end

    # This manages our test state / beaker run stages in an RSpec aware way
    class TestState
      require 'pathname'
      require 'singleton'

      include Singleton

      attr_reader :rspec_config, :options, :logger, :network_manager, :hosts, :node_file

      def hunt_for_file(bare_file, search_path)
        yml_file = bare_file + '.yml'

        possibilities = [bare_file, yml_file].map do |basename|
          possible_search_paths = search_path.map {|paths|
            Array(paths).reduce([[], []]) {|memo, dir|
              memo[0] ||= []
              memo[0] << dir
              memo[1] ||= []
              memo[1] << File.join(Dir.pwd, *memo[0])
              memo
            }[1]
          }.flatten

          possible_search_paths.find do |path|
            File.exists?(File.join(path, basename))
          end
        end

        return possibilities.flatten.compact.first
      end

      def configure!(rspec_config)
        @rspec_config = rspec_config

        defaults   = Beaker::Options::Presets.presets
        env_opts   = Beaker::Options::Presets.env_vars
        @node_file = hunt_for_file(rspec_config.node_set, [rspec_config.node_set_path])

        raise "Could not find #{rspec_config.node_set}" unless node_file

        this_run_dir = File.join('.vagrant', 'beaker_vagrant_files', File.basename(@node_file))
        provisioned = File.exists?(this_run_dir)
        rspec_config.provision = provisioned ? rspec_config.provision : true
        node_opts  = Beaker::Options::HostsFileParser.parse_hosts_file(node_file)
        user_opts  = rspec_config.beaker.merge({
                       :color      => rspec_config.color,
                       :log_level  => 'debug',
                       :quiet      => false,
                       :hosts_file => File.basename(node_file),
                       :provision  => rspec_config.provision
        })

        @options  = defaults.
                      merge(node_opts).
                      merge(env_opts).
                      merge(user_opts)

        key_file  = hunt_for_file(rspec_config.ssh_key, [ENV['HOME'], ['spec', 'support']])
        @options[:ssh][:keys] = [File.expand_path(key_file)]   # Grrr...

        @logger   = Beaker::Logger.new( options )

        @options[:logger] = logger

        @network_manager = Beaker::NetworkManager.new(options, options[:logger])
        @hosts = options['HOSTS'].map do |hostname, info|
          Beaker::Host.create(hostname, options)
        end
      end

      def validate!
        opts = {:color => rspec_config.color}
        Beaker::Utils::Validator.validate(hosts, options[:logger])
      end

      def provision!
        @hosts = network_manager.provision
      end

      def destroy!
        network_manager.cleanup
      end

      def default_setup_steps
        # prepare our env for the test suite
        hosts = Beaker::RSpec::TestState.instance.hosts
        default_host = hosts.find do |host|
          ['default', :default, 'master'].any? do |role|
            host['roles'].include?( role )
          end
        end
        root = Pathname(rspec_config.default_path).parent.realpath
        modname = root.basename.to_s.split('-', 2).pop
        mod_on_node = "#{default_host['distmoduledir']}/#{modname}"
        default_host.exec(Beaker::Command.new( "mkdir -p #{mod_on_node}" ))

        %w{Modulefile manifests templates files
           Puppetfile Gemfile
           tasks Rakefile}.each do |to_trans|

          local_file = File.join(root.to_s, to_trans)

          if File.exists?( local_file )
            default_host.do_scp_to( local_file, "#{mod_on_node}/#{to_trans}", {})
          end
        end

        if File.exists?(File.join(root.to_s, *(Array(rspec_config.setup_manifest).flatten)))
          default_host.exec(Beaker::Command.new("puppet apply #{mod_on_node}/manifests/prerequisites/dev.pp"))
        end

        default_host.exec(Beaker::Command.new( "cd #{mod_on_node}; " +
               "BUNDLE_WITHOUT='ci lint spec pkg' rake deps:ruby; " +
               "LIBRARIAN_PUPPET_PATH=#{default_host['distmoduledir']} rake deps:puppet"))
      end
    end
  end
end

# I hate this, here we set up a prettier way to configure beaker via RSpec
::RSpec.configure do |c|
  c.add_setting :node_set,       :default => ENV['SPEC_NODES'] || 'default.yml'
  c.add_setting :node_set_path,  :default => ENV['SPEC_NODE_PATH'] || ['spec', 'support', 'nodes', 'vagrant']
  c.add_setting :provision,      :default => ENV['SPEC_PROVISION'] == 'true'
  c.add_setting :validate,       :default => ENV['SPEC_VALIDATE'] == 'true'
  c.add_setting :destroy,        :default => ENV['SPEC_DESTROY'] == 'true'
  c.add_setting :ssh_key,        :default => ENV['SPEC_KEYFILE'] || 'insecure_private_key'
  c.add_setting :beaker,         :default => Hash.new
  c.add_setting :setup_steps,    :default => nil
  c.add_setting :setup_manifest, :default => ['manifests', 'prerequisites', 'dev.pp']
end

# Here we inject Beaker's default stages into our RSpec test run
::RSpec.configure do |c|
  c.before :suite do
    # Why yes, I do want to pass around a Singleton as an arg (to another singleton)
    Beaker::RSpec::TestState.instance.configure!(::RSpec.configuration)

    # We have to call `provision!` regardless of whether or not we're
    # really provisioning because it's in this step that the old ip
    # (if it exists) is found
    Beaker::RSpec::TestState.instance.provision!

    if ::RSpec.configuration.validate
      Beaker::RSpec::TestState.instance.validate!
    end

    if ::RSpec.configuration.provision
      Beaker::RSpec::TestState.instance.default_setup_steps
    end
  end

  c.after :suite do
    Beaker::RSpec::TestState.instance.destroy! if ::RSpec.configuration.destroy
  end
end

# This is the minimum needed in an RSpec example to allow using the Beaker DSL
# This is the same thing that would happen if you set:
#   let(:hosts) { Beaker::RSpec::TestState.instance.hosts.dup }
#   ...etc...
# within your tests
::RSpec.configure do |c|
  c.include Beaker::DSL
  c.include Beaker::RSpec::Bridge
end

