#This defined type is responsible for installing gems
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

  $chruby  = '/usr/local/bin/chruby-exec'
  $gem_cmd = "gem install ${gem} ${version_string} --no-ri --no-rdoc"
  $grep    = "grep '^${gem}' ${version_check}"

  exec { "install ${gem} on ${ruby_version}":
    command => "${chruby} ${ruby_version} -- ${gem_cmd}",
    unless  => "${chruby} ${ruby_version} -- gem list | ${grep}",
  }
}
