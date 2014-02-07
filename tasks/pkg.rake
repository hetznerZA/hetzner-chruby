
def compute_dev_version
  Dir.chdir ROOT do
    modfile = File.read('Modulefile')
    version = modfile.match(/\nversion[ ]+['"](.*)['"]/)[1]
    sha     = `git rev-parse HEAD`[0..7]

    raise "Unknown version type: #{version}" if version.include? '-'

    return "#{version}-dev#{sha}"
  end
end

desc 'Package and release a Puppet module to the Forge'
task :pkg => %w{pkg:build pkg:release} do

  require 'bundler'
  Bundler.setup
  require 'puppet_blacksmith'

  puts 'Pushing to remote git repo'
  Blacksmith::Git.new.push!
end

namespace :pkg do

  desc 'Output what the computed dev version would be'
  task :version do
    if STDOUT.tty?
      puts compute_dev_version
    else
      print compute_dev_version
    end
  end

  desc 'Bump module version to specified version (default: dev version)'
  task :bump do
    require 'bundler'
    Bundler.setup

    Dir.chdir ROOT do
      version = ENV['PKG_VERSION'] || compute_dev_version

      modfile = File.read('Modulefile')
      modfile.gsub!(/\n\s*version[ ]+['"](.*)['"]/, "\nversion '#{version}'")

      File.open('Modulefile', 'w') {|f| f.puts modfile }

      puts "Bumped module to dev version: #{version}"
    end
  end

  desc 'Build a releaseable Puppet module package'
  task :build => %w{clean:pkg} do
    require 'bundler'
    Bundler.setup
    require 'puppet/face'

    # This is horrible but otherwise all our fixtures get shipped too!
    # https://tickets.puppetlabs.com/browse/FORGE-56
    class Puppet::ModuleTool::Applications::Builder
      def copy_contents
        Dir[File.join(@path, '*')].each do |path|
          case File.basename(path)
          when *Puppet::ModuleTool::ARTIFACTS
            next
          when /Gemfile\.lock/, /Puppetfile\.lock/, /^modules/
          else
            FileUtils.cp_r path, build_path, :preserve => true
          end
        end
      end
    end

    Puppet['confdir'] = '/dev/null'
    module_tool = Puppet::Face['module', :current]

    module_tool.build('./')
  end

  desc 'Release built module package to the Forge'
  task :release do
    require 'bundler'
    Bundler.setup
    require 'puppet_blacksmith'

    m = Blacksmith::Modulefile.new
    forge = Blacksmith::Forge.new

    forge.url      = ENV['PKG_FORGE']    if ENV['PKG_FORGE']
    forge.username = ENV['PKG_USERNAME'] if ENV['PKG_FORGE']
    forge.password = ENV['PKG_PASSWORD'] if ENV['PKG_FORGE']

    puts "Uploading to Puppet Forge #{forge.username}/#{m.name}"
    forge.push!(m.name)
  end
end

#
#  These are tasks from Puppet-Blacksmith whose
#  value in an actual ci pipeline is suspect
#
#
#  desc 'Git tag with the current module version'
#  task :tag do
#    require 'bundler'
#    Bundler.setup
#    require 'puppet_blacksmith'
#
#    m = Blacksmith::Modulefile.new
#    Blacksmith::Git.new.tag!(m.version)
#  end
#
#  desc 'Bump version and git commit'
#  task :bump_commit => :bump do
#    require 'bundler'
#    Bundler.setup
#    require 'puppet_blacksmith'
#
#    Blacksmith::Git.new.commit_modulefile!
#  end
#
