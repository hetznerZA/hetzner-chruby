class chruby(
  $version       = 'v0.3.7',
  $ruby_prefix   = '/opt/rubies',
  $stage         =  true,
  $staging_root  = '/opt/puppet_staging',
  $user          = 'puppet',
  $group         =  $user,
  $sources_root  = "${staging_root}/sources",
  $download_root = "${staging_root}/downloads",
) {

  file { $ruby_prefix: ensure => 'directory' }

  if $stage {
    class { 'staging':
      path  => $download_root,
      owner => $user,
      group => $group,
    }
  }

  # Pull down and install a tool to manage our versions of Ruby
  staging::deploy { "chruby-${version}.tar.gz":
    target  => $sources_root,
    source  => 'https://github.com/postmodern/chruby/archive/v${version}.tar.gz',
    user    => $user,
    group   => $group,
    creates => "${sources_root}/chruby-${version}",
    require => Class['staging'],
    before  => Exec['install chruby'],
  }

  exec { 'install chruby':
    cwd     => "${sources_root}/chruby-${version}",
    command => 'make install',
    creates => '/usr/local/share/chruby',
    path    => [ '/sbin', '/usr/sbin', '/bin', '/usr/bin' ],
  }

  # This ensures that everyone can use chruby and
  # is necessary for `chruby-exec` to work
  file { '/etc/profile.d/chruby.sh':
    ensure  => 'file',
    content => "source '/usr/local/share/chruby/chruby.sh'",
    require => Exec['install chruby'],
  }
}
