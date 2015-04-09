# Class: tomcat
#
#  Install and configure tomcat with java  
#
#  Parameters
#
#  [*$source_path*]
#  The is the directory from  where the tomcat module will get its setup files and configurations
#
#  [*$java_version*]
#  The parameter checks version of java i.e java 1.7  or java 1.8 
#
#  [*$java_dir*]
#  The is the base directory on which java is deployed.
#
#  [*$platform*]
#  This parameter takes input from the user to check machine platform i.e x86 bit or x64 bit.
#
#  [*$env_path*]
#  The is the parameter which sets java path.
#
#  [*$tomcat_version*]
#  Specify tomcat version which you want to install  
#
#  [*$tomcat_path*]
#  Specify tomcat path 
#
#  [*$javaDownloadURI*]
#  Specify java download url
#
#  [*$tomcat_mirror*]
#  Specify tomcat mirror url
#  
#  [*$tomcat7_build*]
#  Specify tomcat7 build
#
#  [*$tomcat8_build*]
#  Specify tomcat8 build
#
#  [*$tomcat_user*]
#  Specify tomcat run user
#
#  [*$javaDownloadURI*]
#  Specify java download url
class tomcat
      (
      # Define java_version here . 7 or 8 
      $java_version   = hiera('tomcat::java_version',  '8' ),
      # Define java_dir here 
      $java_dir      = hiera('tomcat::java_dir',   '/usr/java' ),
      $use_cache      = hiera('tomcat::use_cache',     false ),
      # Define OS platform here
      $platform       = hiera('tomcat::platform',     'x64' ),
      # Define your source diectory path here.
      $source_path   = hiera('tomcat::source_path',  '/vagrant/modules/tomcat/files' ),
      # Define your environment variable diectory path here.
      $env_path      = hiera('tomcat::env_path',  '/etc/profile.d/java.sh'),
      # Define  tomcat diectory path here.
      $tomcat_path    = hiera('tomcat::tomcat_path',  '/usr/local/tomcat'),
      # Define  tomcat version. 7 or 8 
      $tomcat_version = hiera('tomcat::tomcat_version','8'),
      # Define mirror (you need to point the URL to /apache/tomcat)
      $tomcat_mirror = hiera('tomcat::tomcat_mirror','https://is.it.ucla.edu/mirrors/tomcat'),
      # Define Tomcat7 build
      $tomcat7_build = hiera('tomcat::tomcat7_build','7.0.61'),
      # Define Tomcat8 build
      $tomcat8_build = hiera('tomcat::tomcat8_build','8.0.21'),
      # Define tomcat user
      $tomcat_user    = hiera('tomcat::tomcat_user', 'tomcat'),
      )
      {

# Setting default exec path for this module
Exec { path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin',] }

file {$java_dir:
    ensure   => directory,
    owner    => root,
    group    => root,
}

user { $tomcat_user:
    ensure           => 'present',
    gid              => '8080',
    home             => $tomcat_path,
    password         => '!!',
    password_max_age => '99999',
    password_min_age => '0',
    shell            => '/bin/bash',
    uid              => '8080',
}
group { $tomcat_user:
    ensure           => 'present',
    gid              => '8080',
}
case $platform {
    'x64': {
        $plat_filename = 'x64'
    }
    'x86': {
        $plat_filename = 'i586'
    }
    default: {
        fail("Unsupported platform: ${platform}.  Please define platforms variable")
    }
}

case $java_version {
    '8': {
        $javaDownloadURI = "http://download.oracle.com/otn-pub/java/jdk/8-b132/jdk-8-linux-${plat_filename}.tar.gz"
        $java_home = "${java_dir}/jdk1.8.0"
    }
    '7': {
        $javaDownloadURI = "http://download.oracle.com/otn-pub/java/jdk/7/jdk-7-linux-${plat_filename}.tar.gz"
        $java_home = "${java_dir}/jdk1.7.0"
    }
    default: {
        fail("Unsupported java_version: ${java_version}.  Implement me?")
    }
}

        $installerFilename = inline_template('<%= File.basename(@javaDownloadURI) %>')

if ( $use_cache ){
    notify { 'Using local cache for oracle java': }
            
    file { "${java_dir}/${installerFilename}":
        source  => "puppet:///modules/tomcat/${installerFilename}",
    }
        
    exec { 'get_jdk_installer':
        cwd     =>  $java_dir,
        creates =>  "${java_dir}/jdk_from_cache",
        command => 'touch jdk_from_cache',
        require => File["${java_dir}/jdk-${java_version}-linux-x64.tar.gz"],
        }
} else {
    exec { 'get_jdk_installer':
        cwd     => $java_dir,
        creates => "${java_dir}/${installerFilename}",
        command => "wget -c --no-cookies --no-check-certificate --header \"Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com\" --header \"Cookie: oraclelicense=accept-securebackup-cookie\" \"${javaDownloadURI}\" -O ${installerFilename}",
        timeout => 1200,
        }
    
    file { "${java_dir}/${installerFilename}":
        mode    => '0755',
        owner   => root,
        group   => root,
        require => Exec['get_jdk_installer'],
        }
}

if ( $java_version in [ '7', '8' ] ) {
    exec { 'extract_jdk':
        cwd     => "${java_dir}/",
        command => "tar -xf ${installerFilename}",
        creates => $java_home,
        require => Exec['get_jdk_installer'],
    }
}

if ( $java_version in [ '7', '8' ] ) {
    exec { 'set_java_home':
        command => "echo 'export JAVA_HOME=${java_home}'>> ${env_path}",
        unless  => "grep 'JAVA_HOME=${java_home}' ${env_path}",
        require => Exec['extract_jdk'],
    }
}

    exec { 'java_path':
        command => "echo 'export PATH=\$JAVA_HOME/bin:\$PATH' >> ${env_path}",
        unless  => "grep 'export PATH=\$JAVA_HOME/bin:\$PATH' ${env_path}",
        require => Exec['set_java_home'],
    }
    
    file_line { 'Adding CATALINA_BASE environment variable':
        path    => '/etc/environment',
        line    => "CATALINA_BASE=${tomcat_path}/",
    }

    file_line { 'Adding JAVA_HOME envoronment variable':
        path    => '/etc/environment',
        line    => "CATALINA_BASE=${java_path}/",
    }
    exec { 'set_env':
        command => "bash -c 'source ${env_path}'",
        require => Exec['java_path'];
    }

case $tomcat_version {
    '8': {
        $tomcatDownloadURI  = "${tomcat_mirror}/tomcat-${tomcat_version}/v${tomcat8_build}/bin/apache-tomcat-${tomcat8_build}.tar.gz"
        $web_home           = $tomcat_path
        $tomcat_file_name   = "apache-tomcat-${tomcat8_build}"
        }
    '7': {
        $tomcatDownloadURI  = "${tomcat_mirror}/tomcat-${tomcat_version}/v${tomcat7_build}/bin/apache-tomcat-${tomcat7_build}.tar.gz"
        $web_home           = $tomcat_path
        $tomcat_file_name   = "apache-tomcat-${tomcat7_build}"
        }
    default: {
        fail("Unsupported tomcat_version: ${tomcat_version}.  Implement me?")
        }
}
    
    
if ( $tomcat_version in [ '7', '8' ] ) {
    exec { 'get_tomcat':
        cwd     => '/tmp',
        command => "wget ${tomcatDownloadURI}",
        unless  => "test -e ${tomcat_file_name}.tar.gz",
        timeout => 1200,
        #require => File[$tomcat_path],
        }
}
    
if ( $tomcat_version in [ '7', '8' ] ) {
    exec { 'extract_tomcat':
        cwd     => "/usr/local/",
        command => "tar xzf /tmp/${tomcat_file_name}.tar.gz -C /usr/local/ && ln -s /usr/local/${tomcat_file_name} /usr/local/tomcat ; chown -R $tomcat_user:$tomcat_user ${tomcat_path}/ && rm -f /tmp/${tomcat_file_name}.tar.gz",
        creates => $web_home,
        unless  => "test -e ${tomcat_file_name}",
        require => Exec['get_tomcat'],
        }
}

if ( $tomcat_version in [ '7', '8' ] ) {
    file { '/etc/init.d/tomcat':
        mode    => '0774',
        owner   => root,
        group   => root,
        content => template('tomcat/tomcat.erb'),
        backup  => false,
        require => Exec['extract_tomcat'],
        }
}
    
}
    
    
