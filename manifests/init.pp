class softec_mylvmbackup(
  $password,
  $vgname,
  $lvname,
  $lvsize,
  $user               = 'mylvmbackup',
  $mountdir           = '/var/cache/mylvmbackup/mnt/',
  $backuplv           = '',
  $backupdir          = '/var/cache/mylvmbackup/backup/',
  $relpath            = '',
  $fstype             = 'ext4',
  $suffix             = '_mysql',
  $keep               = '14',
  $notification_email = 'backup@softecspa.it',
  $log_err            = '/var/log/cron/daily/mylvmbackup.stderr.log',
  $nagios_hostname    = $::nagios_fqdn,
  $clustername        = $cluster,
  $send_nsca          = true,
  $nagios_monitor_host= $::hostname,
) {

  $config = '/etc/mylvmbackup.conf'
  package {
    'mylvmbackup':
      ensure  => installed,
      require => Class['mysql::server'];
    'liblzo2-2':
      ensure  => installed;
    'lzop':
      ensure  => installed;
    'mutt':
      ensure  => installed;
    'lvm2':
      ensure  => installed;
  }

  File {
    require => Package['mylvmbackup']
  }

  file {
    $mountdir:
      ensure    => directory,
      owner     => 'root',
      group     => 'root',
      mode      => 0775;
    $backupdir:
      ensure    => directory,
      owner     => 'root',
      group     => 'root',
      mode      => 0775;
    $config:
      ensure    => present,
      owner     => 'root',
      group     => 'admin',
      mode      => 0640,
      content   => template('softec_mylvmbackup/mylvmbackup.conf.erb');
  }

  mysql_user {"$user@%":
    ensure        => present,
    password_hash => mysql_password($password)
  }

  mysql_grant{"$user@%/*.*":
    ensure      => present,
    options     => ['GRANT'],
    privileges  => [ 'REPLICATION CLIENT', 'RELOAD' ],
    table       => ['*.*'],
    user        => "$user@%"
  }

  softec_mylvmbackup::hook { 'backupfailure':
    opts => {
      'notification_email'  => $notification_email,
      'log_err'             => $log_err,
    }
  }

  softec_mylvmbackup::hook { 'backupsuccess':
    opts  => {
      'keep'  =>  $keep
    }
  }

  softec_mylvmbackup::hook { 'logerr':
      opts  =>  {
        'notification_email' =>  $notification_email,
        'log_err'            =>  $log_err,
      },
      tpl   =>  'softec_mylvmbackup/backupfailure_hook.sh.erb';
  }

  cron::entry {
    "mylvmbackup":
      frequency   =>  "daily",
      command     =>  "umask 0077; mylvmbackup --quiet; umask 0022",
      nice        =>  "19",
      ionice_cls  =>  "3"
  }

  if ($send_nsca) {

    $nagios_shortname = inline_template("<%= @nagios_hostname.split('.').at(0) %>")

    @@nagios::check { "mylvmbackup-cluster${clustername}":
      host                  => $nagios_monitor_host,
      checkname             => 'no-backup-report',
      service_description   => "mylvmbackup-${clustername}",
      params                => "!\"Mylvmbackup-${clustername} non effettuato\"",
      target                => "mylvmbackup.cfg",
      notifications_enabled => 1,
      freshness_threshold   => 87000,
      service_template      => 'passive-bkp',
      contact_groups        => 'sistemi',
      notification_period   => 'workhours',
      tag                   => "nagios_check_mylvmbackup_${nagios_shortname}",
    }
  }
}
