
$pkgs = $osfamily ? {
  RedHat => [ 'git', 'ruby-devel',
              'libxml2-devel', 'libxslt-devel',
              'gcc', 'gcc-c++' ],
}

$gems = [ 'bundler', 'rake' ]

package { $pkgs: ensure => present }
package { $gems: ensure => present, provider => gem }

