#!/bin/bash
#set -euo pipefail
set -o pipefail

RED='\E[1;31m'      # red
GREEN='\E[1;32m'    # green
YELLOW='\E[1;33m'   # yellow
BLUE='\E[1;34m'     # blue
PINK='\E[1;35m'     # pink
RES='\E[0m'         # clear

_check() {
if [[ $? -ne 0 ]]; then
  echo -e "${RED} $1 Error${RES}"
  exit 1
else
  echo -e "${GREEN} $1 Done${RES}"
fi
}

############ Disabled artifacts repo of SEC packages ##########
echo -e "\n\033[5;4;47;34m Disable SEC packages \033[0m\n"
sed -i 's/enabled = 1/enabled = 0/g' /etc/yum.repos.d/artifacts-cybersec-rocky8-tlscontact.repo
sed -i 's/enabled = 1/enabled = 0/g' /etc/yum.repos.d/artifacts-rocky8-tlscontact.repo
_check disable_sec_repo

########## Prerequisite for Rocky Linux packages for Asterisk and FreePBX ###########
echo -e "\n\033[5;4;47;34m ===== 1. Update and Install all packages (~45 minutes) ===== \033[0m\n"
sleep 3

### Disable and disable SELinux
echo -e "\n\033[5;4;47;34m Configuring SElinux \033[0m\n"
sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/selinux/config
sed -i 's/\(^SELINUX=\).*/\SELINUX=permissive/' /etc/sysconfig/selinux
setenforce 0
_check disable_selinux

### update system
echo -e "\n\033[5;4;47;34m Update system \033[0m\n"
dnf -y update
_check update_system

### add epel repository and install it
echo -e "\n\033[5;4;47;34m Install fedora epel \033[0m\n"
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
_check install_epel_repository

### enable powertools on rocky linux 8
echo -e "\n\033[5;4;47;34m Enable powertools \033[0m\n"
dnf config-manager --set-enabled powertools
_check enable_powertools

### install dev tools and group install
# new script --> dnf -y groupinstall  "Development Tools"
# group install core base from old script
echo -e "\n\033[5;4;47;34m Install group dev tools \033[0m\n"
while [[ $(yum grouplist installed | grep "Development Tools"|wc -l) == "0" ]];do
yum -y groupinstall core base "Development Tools"
done
_check install_dev_tools_core_base

### install dependencies packages
# mysql-connector-odbc is not found
# python-devel is not found
# command: alternatives --config python
echo -e "\n\033[5;4;47;34m Install package dependencies \033[0m\n"
dev_pkg="lynx git wget vim net-tools sqlite-devel psmisc ncurses-devel libtermcap-devel newt-devel libxml2-devel libtiff-devel gtk2-devel libtool subversion
kernel-devel crontabs cronie-anacron tftp-server sox audiofile-devel uuid-devel python3-devel texinfo libuuid-devel libedit libedit-devel ngrep"
yum -y install $dev_pkg
_check install_packages_dependencies

### install Jansson for C Library
echo -e "\n\033[5;4;47;34m Install Jansson from github \033[0m\n"
cd /home/rocky/
git clone https://github.com/akheron/jansson.git
cd jansson
autoreconf -i
./configure --prefix=/usr/
make
make install
_check install_Jansson_from_github_for_asterisk

### install PJSIP for SIP, STUN, RTP, etc.
echo -e "\n\033[5;4;47;34m Install PJ Project from github \033[0m\n"
cd /home/rocky/
git clone https://github.com/pjsip/pjproject.git
cd pjproject
./configure CFLAGS="-DNDEBUG -DPJ_HAS_IPV6=1" --prefix=/usr --libdir=/usr/lib64 --enable-shared --disable-video --disable-sound --disable-opencore-amr
make dep
make
make install
ldconfig
_check install_PJSIP_from_github_for_asterisk

### install prerequisite for freePBX
echo -e "\n\033[5;4;47;34m Install php and other prerequisites for FreePBX \033[0m\n"
dnf -y install mariadb mariadb-server
dnf -y install sendmail sendmail-cf gnutls-devel unixODBC
# install httpd, delete default index and set firewall
dnf -y install @httpd
while [[ $(yum list installed nodejs |grep nodejs|wc -l) == "0" ]];do
yum install -y nodejs
done
# install php extensions as required
dnf -y install yum-utils
dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm
dnf module -y reset php
dnf module -y install php:remi-7.4
# install php extensions
dnf install -y php php-pear php-cgi php-common php-curl php-mbstring php-gd php-mysqlnd php-gettext php-bcmath php-zip php-xml php-json php-process php-snmp
# this command "it is already installed and is the same as the released version 1.4.3"
#pear install Console_Getopt
_check install_freepbx_prerequisite

############ Install Asterisk and Configure ##########
echo -e "\n\033[5;4;47;34m ===== 2. Install and Configure Asterisk (~30 minutes) ===== \033[0m\n"
sleep 3
echo -e "\n\033[5;4;47;34m Download and install Asterisk \033[0m\n"
cd /home/rocky/
if  [ ! -e "asterisk-18-current.tar.gz" ]; then
wget -c http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18-current.tar.gz
fi
tar xvfz asterisk-18-current.tar.gz
cd asterisk-18*/
# 3 lines below is configure command from our old script (not from the web)
./configure --with-pjproject-bundled --with-jansson-bundled --with-iksemel --libdir=/usr/lib64
./configure --with-pjproject-bundled --with-jansson-bundled --without-iksemel --libdir=/usr/lib64
make menuselect.makeopts
menuselect/menuselect --enable app_macro --enable format_mp3 menuselect.makeopts
_check install_asterisk_and_makemenuselect

### install asterisk prerequisite
./contrib/scripts/install_prereq install
./contrib/scripts/get_mp3_source.sh
_check install_asterisk_prerequisite

### build asterisk and install
echo -e "\n\033[5;4;47;34m Build asterisk  \033[0m\n"
make
make install
make samples
make config
ldconfig
_check build_asterisk

### setup asterisk user
echo -e "\n\033[5;4;47;34m Configure Asterisk  \033[0m\n"
# this is 1 line below from old script
id -u asterisk 2>/dev/null || adduser asterisk -m -c "Asterisk User"
usermod -aG audio,dialout asterisk
chown -R asterisk.asterisk /etc/asterisk /var/{lib,log,spool}/asterisk /usr/lib64/asterisk
# uncomment AST_USER and AST_GROUP
sed -i 's/#AST_USER=\"asterisk\"/AST_USER=\"asterisk\"/g' /etc/sysconfig/asterisk
sed -i 's/#AST_GROUP=\"asterisk\"/AST_GROUP=\"asterisk\"/g' /etc/sysconfig/asterisk
# uncomment  runuser = asterisk and rungroup = asterisk --> please use sed command on this
sed -i 's/;runuser = asterisk/runuser = asterisk/' /etc/asterisk/asterisk.conf
sed -i 's/;rungroup = asterisk/rungroup = asterisk/' /etc/asterisk/asterisk.conf
_check configure_asterisk

### system control restart and enable service
echo -e "\n\033[5;4;47;34m Restart asterisk  \033[0m\n"
systemctl restart asterisk
systemctl enable asterisk
_check restart_asterisk

### open asterisk command
#asterisk -rvvvvvv
#core show uptime

############ Install FreePBX and Configure MySQL ##########
echo -e "\n\033[5;4;47;34m ===== 3. Install and Configure FreePBX (~30 minutes) ===== \033[0m\n"
sleep 3
echo -e "\n\033[5;4;47;34m Configure MySQL MariaDB \033[0m\n"
### Enable MariaDB and config the user and security
systemctl enable --now mariadb

### setup the mysql root password here
#mysql_secure_installation
#UPDATE mysql.user SET Password=PASSWORD('${db_root_password}') WHERE User='root';

mysqladmin password "fgmn88.1706"
mysql --user=root --password=fgmn88.1706 <<_EOF_
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
_EOF_
_check configure_mysql

### configure web server
echo -e "\n\033[5;4;47;34m Configure web server \033[0m\n"
rm -f /var/www/html/index.html
firewall-cmd --add-service={http,https} --permanent
firewall-cmd --reload
_check configure_web_server

### edit upload max size to 20M --> please change it into sed command
echo -e "\n\033[5;4;47;34m Configure PHP \033[0m\n"
sed -i 's/;upload_max_filesize = 2M/upload_max_filesize = 20M/' /etc/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 20M/' /etc/php.ini
### restart php-fpm and httpd
systemctl restart php-fpm httpd
systemctl enable php-fpm httpd
_check configure_php

### make sure Apache modification
echo -e "\n\033[5;4;47;34m Configure Apache \033[0m\n"
sudo sed -i 's/\(^memory_limit = \).*/\1128M/' /etc/php.ini
sudo sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/httpd/conf/httpd.conf
sudo sed -i 's/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
sudo sed -i 's/\(^user = \).*/\1asterisk/' /etc/php-fpm.d/www.conf
sudo sed -i 's/\(^group = \).*/\1asterisk/' /etc/php-fpm.d/www.conf
sudo sed -i 's/\(^listen.acl_users = \).*/\1apache,nginx,asterisk/' /etc/php-fpm.d/www.conf
_check configure_apache

### install freepbx package
echo -e "\n\033[5;4;47;34m Download, install, configure FreePBX \033[0m\n"
cd /home/rocky
if  [ ! -e "freepbx-16.0-latest.tgz" ]; then
wget -c http://mirror.freepbx.org/modules/packages/freepbx/7.4/freepbx-16.0-latest.tgz
fi
tar vxfz freepbx-16.0-latest.tgz
cd freepbx
systemctl stop asterisk
./start_asterisk start
# setup the database password here
./install --webroot=/var/www/html -n --dbuser root --dbpass fgmn88.1706
_check install_freepbx

### Install freePBX fwconsole modules
echo -e "\n\033[5;4;47;34m Configure fwconsole \033[0m\n"
fwconsole ma disablerepo commercial
# start: this is from old script (different from the blog)
# sudo fwconsole ma disablerepo commercial
# sudo fwconsole ma installall
# sudo fwconsole ma delete firewall
# sudo fwconsole reload
# sudo fwconsole restart
fwconsole ma refreshsignatures
fwconsole ma downloadinstall pm2
fwconsole ma downloadinstall asteriskinfo
fwconsole ma downloadinstall logfiles
fwconsole ma downloadinstall certman
fwconsole ma upgradeall
# end: from old script

# this is from old script but not working
#fwconsole ma delete firewall
fwconsole reload
fwconsole restart
_check configure_fwconsole

### Configure FreePBX service
echo -e "\n\033[5;4;47;34m Configure FreePBX service \033[0m\n"
# restart httpd and php-fpm services
systemctl restart httpd php-fpm
# create systemd unit for auto-starting for services
tee /etc/systemd/system/freepbx.service<<EOF
[Unit]
Description=FreePBX VoIP Server
After=mariadb.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/fwconsole start -q
ExecStop=/usr/sbin/fwconsole stop -q
[Install]
WantedBy=multi-user.target
EOF
# enable the service to autostart
systemctl daemon-reload
systemctl enable freepbx
_check configure_freepbx_service

### set permission automatically and then reload freepbx
echo -e "\n\033[5;4;47;34m Configure FreePBX permissions \033[0m\n"
fwconsole chown
fwconsole reload
_check configure_freepbx_permission

this_ip=`ifconfig | grep -m 1 "inet 10*" | cut -c 14-25`
if [ -z "$this_ip" ]
then
  echo "ip not found"
else
  echo -e "\n\033[5;4;47;34m Congrats! All done, please try to open https://$this_ip\n Also run command asterisk -rv\n then type core show uptime \033[0m\n"
fi
