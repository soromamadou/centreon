FROM debian
### Etape 1: Mise à jour 
##deb http://deb.debian.org/debian stretch main non-free contrib
##deb http://deb.debian.org/debian stretch-updates main non-free contrib
##deb http://security.debian.org stretch/updates main non-free contrib


RUN apt-get update && apt-get upgrade  -y && apt-get install ssh 
### Etape 2: Centreon Clib
RUN apt-get install -y\
    wget build-essential cmake 

RUN cd /usr/local/src &&
    wget https://s3-eu-west-1.amazonaws.com/centreon-download/public/centreon-clib/centreon-clib-1.4.2.tar.gz &&
    tar xzf centreon-clib-1.4.2.tar.gz &&
    cd centreon-clib-1.4.2/build

RUN cmake \
       -DWITH_TESTING=0 \
       -DWITH_PREFIX=/usr  \
       -DWITH_SHARED_LIB=1 \
       -DWITH_STATIC_LIB=0 \
       -DWITH_PKGCONFIG_DIR=/usr/lib/pkgconfig .
RUN make &&
    make install
### Etape3: Connecteurs centreon
## PERL connector
RUN apt-get install -y \
    libperl-dev

RUN cd /usr/local/src &&
    wget https://s3-eu-west-1.amazonaws.com/centreon-download/public/centreon-connectors/centreon-connector-1.1.2.tar.gz &&
    tar xzf centreon-connector-1.1.2.tar.gz &&
    cd centreon-connector-1.1.2/perl/build

RUN cmake \
    -DWITH_PREFIX=/usr \
    -DWITH_PREFIX_BINARY=/usr/lib/centreon-connector  \
    -DWITH_CENTREON_CLIB_INCLUDE_DIR=/usr/include \
    -DWITH_TESTING=0 .

RUN make &&
    make install

## SSH connector
RUN apt-get install -y \
    libssh2-1-dev libgcrypt11-dev 

RUN cd /usr/local/src/centreon-connector-1.1.2/ssh/build
RUN cmake \
    -DWITH_PREFIX=/usr \
    -DWITH_PREFIX_BINARY=/usr/lib/centreon-connector  \
    -DWITH_CENTREON_CLIB_INCLUDE_DIR=/usr/include \
    -DWITH_TESTING=0 .

RUN make &&
    make install

### Etape4: Centreon Engine
RUN groupadd -g 6001 centreon-engine
RUN useradd -u 6001 -g centreon-engine -m -r -d /var/lib/centreon-engine -c "Centreon-engine Admin" -s /bin/bash centreon-engine

RUN apt-get install -y \
    libcgsi-gsoap-dev \
    zlib1g-dev \
    libssl-dev \
    libxerces-c-dev

RUN cd /usr/local/src &&
    wget https://s3-eu-west-1.amazonaws.com/centreon-download/public/centreon-engine/centreon-engine-1.7.2.tar.gz &&
    tar xzf centreon-engine-1.7.2.tar.gz &&
    cd centreon-engine-1.7.2/build/

RUN cmake  \
    -DWITH_CENTREON_CLIB_INCLUDE_DIR=/usr/include  \
    -DWITH_CENTREON_CLIB_LIBRARY_DIR=/usr/lib  \
    -DWITH_PREFIX=/usr  \
    -DWITH_PREFIX_BIN=/usr/sbin  \
    -DWITH_PREFIX_CONF=/etc/centreon-engine  \
    -DWITH_USER=centreon-engine  \
    -DWITH_GROUP=centreon-engine  \
    -DWITH_LOGROTATE_SCRIPT=1 \
    -DWITH_VAR_DIR=/var/log/centreon-engine  \
    -DWITH_RW_DIR=/var/lib/centreon-engine/rw  \
    -DWITH_STARTUP_DIR=/etc/init.d  \
    -DWITH_PKGCONFIG_SCRIPT=1 \
    -DWITH_PKGCONFIG_DIR=/usr/lib/pkgconfig  \
    -DWITH_TESTING=0  .

RUN make &&
    make install
#Ajout de centreon au demarrage auto 
RUN update-rc.d centengine defaults

### Etape 5: Installation des Plugins pour Centreon-Engine
RUN apt-get install -y \
    libgnutls28-dev \
    libssl-dev \
    libkrb5-dev \
    libldap2-dev \
    libsnmp-dev \
    gawk \
    libwrap0-dev \
    libmcrypt-dev \
    smbclient \
    fping \
    gettext \
    dnsutils \
    libmodule-build-perl\
    mariadb-server-10.1\
    php7.0

## Plugins Nagios
RUN cd /usr/local/src &&
    wget http://nagios-plugins.org/download/nagios-plugins-2.2.1.tar.gz &&
    tar -xzf nagios-plugins-2.2.1.tar.gz &&
    cd nagios-plugins-2.2.1

RUN ./configure --with-nagios-user=centreon-engine --with-nagios-group=centreon-engine --prefix=/usr/lib/nagios/plugins --libexecdir=/usr/lib/nagios/plugins --enable-perl-modules --with-openssl=/usr/bin/openssl &&
    make && 
    make install

## Plugins Centreon
RUN apt-get install -y \
    libxml-libxml-perl\
    libjson-perl \
    libwww-perl \
    libxml-xpath-perl \
    libnet-telnet-perl \
    libnet-ntp-perl \
    libnet-dns-perl \
    libdbi-perl \
    libdbd-mysql-perl \
    libdbd-pg-perl
RUN apt-get install -y \
    git-core                ## to be remove

RUN cd /usr/local/src &&
    git clone https://github.com/centreon/centreon-plugins.git

RUN cd centreon-plugins &&
    chmod +x centreon_plugins.pl && 
    mkdir -p /usr/lib/centreon/plugins &&
    cp -R * /usr/lib/centreon/plugins/

### Partie 6: Centreon-Broker
RUN groupadd -g 6002 centreon-broker &&
    useradd -u 6002 -g centreon-broker -m -r -d /var/lib/centreon-broker -c "Centreon-broker Admin"  -s /bin/bash centreon-broker &&
    usermod -aG centreon-broker centreon-engine

RUN apt-get install -y \
    librrd-dev \
    libqt4-dev \
    libqt4-sql-mysql \
    libgnutls28-dev \
    lsb-release

RUN cd /usr/local/src &&
    wget https://s3-eu-west-1.amazonaws.com/centreon-download/public/centreon-broker/centreon-broker-3.0.7.tar.gz &&
    tar xzf centreon-broker-3.0.7.tar.gz &&
    cd centreon-broker-3.0.7/build

RUN cmake \
     -DWITH_DAEMONS='central-broker;central-rrd' \
     -DWITH_GROUP=centreon-broker \
     -DWITH_PREFIX=/usr  \
     -DWITH_PREFIX_BIN=/usr/sbin  \
     -DWITH_PREFIX_CONF=/etc/centreon-broker  \
     -DWITH_PREFIX_LIB=/usr/lib/centreon-broker \
     -DWITH_PREFIX_VAR=/var/lib/centreon-broker \
     -DWITH_PREFIX_MODULES=/usr/share/centreon/lib/centreon-broker \
     -DWITH_STARTUP_DIR=/etc/init.d \
     -DWITH_STARTUP_SCRIPT=auto \
     -DWITH_TESTING=0 \
     -DWITH_USER=centreon-broker .

RUN make &&
    make install

#apt-get install sudo tofrodos bsd-mailx lsb-release mysql-server libmysqlclient18 libdatetime-perl \
#    apache2 apache2-mpm-prefork php5 php5-mysql php-pear php5-intl php5-ldap php5-snmp php5-gd php5-sqlite \
#    rrdtool librrds-perl libconfig-inifiles-perl libcrypt-des-perl libdigest-hmac-perl \
#    libdigest-sha-perl libgd-perl snmp snmpd libnet-snmp-perl libsnmp-perl nagios-plugins