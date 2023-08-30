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

########## Join to AD with realmd ##########

# install necessary packages
dnf -y install realmd oddjob oddjob-mkhomedir sssd adcli 
# this one below might be no need?
dnf -y install samba-common samba-common-tools krb5-workstation openldap-clients 
# package not found: policycoreutils-python
_check install_package_for_join_AD

# join to AD
read -p "Enter your a.xxx.xxx username to join AD: " USER
realm join --user=$USER tls.ad -v
_check join_AD

# permit IT adm users group
realm permit -g gu.users_it_adm.usr -v
_check permit_groups
