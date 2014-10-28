define softec_mylvmbackup::hook(
  $tpl=false,
  $opts={},
  $ensure=present
) {

  if $tpl {
    $tplname = $tpl
  } else {
    $tplname = "softec_mylvmbackup/${name}_hook.sh.erb"
  }

  $directory = '/usr/share/mylvmbackup/'
  file {
    "${directory}/${name}":
      ensure  => $ensure,
      owner   => 'root',
      group   => 'root',
      mode    => '0775',
      content => template($tplname),
      require => [
        Package['mylvmbackup'],
        Package['mutt']
      ]
  }
}
