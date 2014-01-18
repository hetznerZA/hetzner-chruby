require 'rspec-puppet'
require 'yarjuf'

fixtures = File.expand_path(File.join(__FILE__, '..', 'fixtures'))
mmm = File.join( fixtures, 'modules' )
lib_fxtrs = File.expand_path(File.join(__FILE__, '..', '..', 'modules'))

RSpec.configure do |c|
  c.module_path  = [mmm, lib_fxtrs].join( File::PATH_SEPARATOR )
  c.manifest_dir = File.join( fixtures, 'manifests' )
end
