#Base class to drive chruby gem installation
class chruby(
  $version       = '0.3.7',
  $ruby_prefix   = '/opt/rubies',
  $staging       =  true,
  $staging_root  = '/opt/puppet_staging',
  $user          = 'puppet',
  $group         =  $user,
  $sources_root  =  undef,
  $download_root =  undef
) {

  $sources_dest = $sources_root ? {
    undef   => "${staging_root}/sources",
    default => $sources_root
  }

  $download_dest = $download_root ? {
    undef   => "${staging_root}/downloads",
    default => $download_root
  }

  file { [ $ruby_prefix, $staging_root, $sources_dest ]:
    ensure => 'directory',
    owner  =>  $user,
    group  =>  $group,
  }

  if $staging {
    class { 'staging':
      path  => $download_dest,
      owner => $user,
      group => $group,
    }
  }

  # Pull down and install a tool to manage our versions of Ruby
  staging::deploy { "chruby-v${version}.tar.gz":
    target  => $sources_dest,
    source  => "https://github.com/postmodern/chruby/archive/v${version}.tar.gz",
    user    => $user,
    group   => $group,
    creates => "${sources_dest}/chruby-${version}",
    require => Class['staging'],
    before  => Exec['install chruby'],
  }

  exec { 'install chruby':
    cwd     => "${sources_dest}/chruby-${version}",
    command => 'make install',
    creates => '/usr/local/share/chruby',
    path    => [ '/sbin', '/usr/sbin', '/bin', '/usr/bin' ],
  }

  # This ensures that everyone can use chruby and
  # is necessary for `chruby-exec` to work
  file { '/etc/profile.d/chruby.sh':
    ensure  => 'file',
    content => '. "/usr/local/share/chruby/chruby.sh"',
    require => Exec['install chruby'],
  }
}
