
desc 'Run all tests'
task :spec => %w{spec:unit spec:system}

namespace :spec do
  desc 'Run rspec-puppet'
  task :unit do
    success      =  false
    rspec        = 'bundle exec rspec '
    pattern_opts = '-P "spec/unit/**/*_spec.rb" '
    format_opts  =  ENV['SPEC_FORMAT'] || '--color'
    Dir.chdir ROOT do
      success = system( rspec + pattern_opts + format_opts )
    end

    exit 1 unless success
  end

  desc 'Run beaker-rspec'
  task :system do
    success      =  false
    rspec        = 'bundle exec rspec '
    pattern_opts = '-P "spec/system/**/**_spec.rb" '
    format_opts  =  ENV['SPEC_FORMAT'] || '--color'
    Dir.chdir ROOT do
      success = system( rspec + pattern_opts + format_opts )
    end

    exit 1 unless success
  end
end

namespace :help do
  desc 'Help with how to use and write tests'
  task :spec do
    pager = ENV['PAGER'] || 'less'
    IO.popen(pager, 'w') { |f| f.puts SPEC_HELP }
  end
end

SPEC_HELP = <<SPEC_HELP_EOS

SPEC_HELP_EOS
