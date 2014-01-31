require 'rspec-puppet'
require 'yarjuf'

modules   = File.expand_path(File.join(__FILE__, '..', '..', 'modules'))
manifests = File.expand_path(File.join(__FILE__, '..', '..', '.tmp'))

RSpec.configure do |c|
  c.module_path  = modules
  c.manifest_dir = manifests
end
