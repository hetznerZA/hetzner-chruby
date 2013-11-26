define chruby::install_gem(
  $gem          = $title,
  $gem_version  = undef,
  $ruby_version = '1.9'
) {

  if $gem_version {
    $version_check  = "| grep ${gem_version}"
    $version_string = "-v${gem_version}"
  } else {
    $version_check  = ''
    $version_string = ''
  }

  exec { "install ${gem}":
    command => "/usr/local/bin/chruby-exec ${ruby_version} -- gem install ${gem} ${version_string} --no-ri --no-rdoc",
    unless  => "/usr/local/bin/chruby-exec ${ruby_version} -- gem list | grep '^${gem}' ${version_check}",
  }
}
