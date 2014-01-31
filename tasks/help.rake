
desc 'Print this help message'
task :help do
  system 'rake -T'
end

namespace :help do
  desc 'Help with how to use and extend rake'
  task :rake do
    pager = ENV['PAGER'] || 'less'
    IO.popen(pager, 'w') { |f| f.puts RAKE_HELP }
  end
end

RAKE_HELP = <<RAKE_HELP_EOS

## How to use rake

        You've probably already got a good grasp on calling rake if you've
    made it this far.  Two things users should note however are it's
    interactions with Bundler and passing parameters to rake tasks.

        You can, and should, call rake prefixed with `bundle exec' to ensure
    that rake is loaded within your modules proper Ruby environment.  You
    should do this regardless of whether or not you follow the advice below
    on how to write your own rake tasks.

        There are many ways to pass information into Ruby tasks, two are
    the most common: setting an environment variable prior to the rake
    invocation or passing explicit parameters after the task.  This is what
    it looks like to pass a parameter to a rake task via Rake's parameter
    handling:

        $ rake my:task foo bar baz

    The most common form of passing parameters to rake tasks however is via
    environment variables. This looks like:

        $ MY_VAR=foo YOUR_VAR=bar rake my:task


## How to add your own rake tasks

        To create your own rake tasks you simply create a ruby script in
    tasks/.  This file should be named after your namespace and end with
    the suffix '.rake'.

    Conventions and Best Practices:

      * Have a top level task named after the namespace that calls
        (depends on) all (or at least important) tasks from the namespace.

      * Require any external gems within your rake task so that a user can
        run `rake -T` (`rake help' or just `rake' here) without having
        already bootstrapped your gem dependencies.

      * Ensure your rake task runs within the project's Ruby environment
        by requiring Bundler within your task and then calling
        `Bundler.setup' prior to requiring any of your external gem
        dependencies.

      * Ensure when shelling out to an external command to prefix the
        command with `bundle exec' if it's calling executables delivered
        via a Ruby gem.

      * Use environment variables for inputs to your tasks.

      * Create a help task for your namespace if the tasks can take
        parameters or the workflow is complicated.  Name your help task
        after your namespace but put it in he help namespace so it can be
        called like `rake help:yournamespace'.  This is the boilerplate to
        do so:
            ```ruby
              namespace :help do
                task :mynamespace do
                  pager = ENV['PAGER'] || 'less'
                  IO.popen(pager, 'w') { |f| f.puts MY_HELP_TEXT }
                end
              end

              MY_HELP_TEXT = <<TEXT_EOS
              TEXT_EOS
            ```

      * For help with Rake see:
          http://www.stuartellis.eu/articles/rake/

      * For general help with Ruby honestly try StackOverflow,
          review the core and stdlib API's at: http://ruby-doc.org/,
          gem API docs at http://rdoc.info/ or if you want a book
          the best survey of Ruby is still probably the Pickaxe:
          http://pragprog.com/book/ruby4/programming-ruby-1-9-2-0

RAKE_HELP_EOS
