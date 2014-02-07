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
      require 'beaker/dsl'
      include Beaker::DSL

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

          found = possible_search_paths.find do |path|
            File.exists?(File.join(path, basename))
          end

          File.join(found, basename) if found
        end

        possibilities.flatten.compact.first
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
                       :provision  => rspec_config.provision,
                       :type       => rspec_config.puppet_type,
                       :pe_dir     => rspec_config.pe_source
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

      def setup_from_forge( forge, version )
        default_host = hosts.find do |host|
          ['default', :default, 'master'].any? do |role|
            host['roles'].include?( role )
          end
        end
        root = Pathname(rspec_config.default_path).parent.realpath.to_s
        modfile = File.read(File.join(root, 'Modulefile'))
        modname = modfile.match(/\n*\s*name\s+['"](.*)['"]/)[1]
        default_host.exec(
          Beaker::Command.new(
            "puppet module install #{modname} " +
            "--version #{version} " +
            "--module_repository #{forge}"))
      end

      def setup_from_source
        # prepare our env for the test suite
        default_host = hosts.find do |host|
          ['default', :default, 'master'].any? do |role|
            host['roles'].include?( role )
          end
        end
        root = Pathname(rspec_config.default_path).parent.realpath.to_s
        modfile = File.read(File.join(root, 'Modulefile'))
        modname = modfile.match(/\n*\s*name\s+['"](.*)['"]/)[1].split(/[-\/]/, 2).pop
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

      def ensure_puppet_enterprise
        install_pe
      end

      def default_setup_steps_for( type, forge, version )
        if type == 'foss'
          if forge
            setup_from_forge forge, version
          else
            setup_from_source
          end
        else
          ensure_puppet_enterprise
          if forge
            setup_from_forge forge, version
          else
            setup_from_source
          end
        end
      end
    end
  end
end

# I hate this, here we set up a prettier way to configure beaker via RSpec
::RSpec.configure do |c|
  if ENV['SPEC_NODE_PATH']
    search_path = ENV['SPEC_NODE_PATH'].split(' ')
  else
    search_path = %w{spec support nodes vagrant}
  end

  c.add_setting :node_set,       :default => ENV['SPEC_NODES'] || 'default'
  c.add_setting :node_set_path,  :default => search_path
  c.add_setting :provision,      :default => ENV['SPEC_PROVISION'] == 'true'
  c.add_setting :validate,       :default => ENV['SPEC_VALIDATE'] == 'true'
  c.add_setting :destroy,        :default => ENV['SPEC_DESTROY'] == 'true'
  c.add_setting :ssh_key,        :default => ENV['SPEC_KEYFILE'] || 'insecure_private_key'
  c.add_setting :puppet_type,    :default => ENV['SPEC_PUPPET_TYPE'] || 'foss'
  c.add_setting :module_version, :default => ENV['SPEC_VERSION']
  c.add_setting :forge,          :default => ENV['SPEC_FORGE']
  c.add_setting :beaker,         :default => Hash.new
  c.add_setting :setup_steps,    :default => nil
  c.add_setting :setup_manifest, :default => ['manifests', 'prerequisites', 'dev.pp']
  c.add_setting :pe_source,      :default => ENV['SPEC_PE_SOURCE'] || 'http://pe-releases.puppetlabs.net/3.1.2'
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
      Beaker::RSpec::TestState.
        instance.
        default_setup_steps_for(::RSpec.configuration.puppet_type,
                                ::RSpec.configuration.forge,
                                ::RSpec.configuration.module_version )
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

