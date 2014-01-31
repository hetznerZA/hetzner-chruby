source ENV['GEM_SOURCE'] || "https://rubygems.org"

# Task runner
gem 'rake',   '10.0'

# Test runner
# We pin to the 2.14 series because we don't yet want to
# deal with the deprecation warnings in 2.99 or the API
# breakage in 3.0
gem 'rspec', '~> 2.14.0'

# We need puppet to do catalog compilation (for rspec-puppet)
# and syntax checking
gem 'puppet', '~> 3.4.0'

# "Spec" test Puppet....
gem 'rspec-puppet', '1.0.1'

# "System" test Puppet....
gem 'beaker-rspec'

# Yet Another RSpec JUnit Formatter,
# Allows Jenkins to easily understand the test output
gem 'yarjuf', '1.0.4'

# Bundler like utility for Puppet
# Need pre-release version for 'modulefile' support
gem 'librarian-puppet',
  :github => 'rodjek/librarian-puppet',
  :ref    => '772a9b27718aeee2d21521539c90a27a1e08be71'

# Util for linting
# Has seen a major refactor since last release
gem 'puppet-lint',
  :github => 'rodjek/puppet-lint',
  :ref    => 'a4bb1e85c367dfb1137b1357c67ef2609c63ed9c'

# Utils for publishing puppet modules from the command line
gem 'puppet-blacksmith'

