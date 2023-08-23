sed -i 's/^UUID=/#UUID=/' /etc/sysconfig/network-scripts/ifcfg-ens3

# check ipaddr
if grep -q "IPADDR" /etc/sysconfig/network-scripts/ifcfg-ens3; then
  echo "Error: IP address is already set"
else
  read -p "Enter IP address: " IPADDR
  echo "IPADDR=$IPADDR" >> /etc/sysconfig/network-scripts/ifcfg-ens3
fi

# check netmask
if grep -q "NETMASK" /etc/sysconfig/network-scripts/ifcfg-ens3; then
  echo "Error: Netmask is already set"
else
  read -p "Enter Netmask: " NETMASK
  echo "NETMASK=$NETMASK" >> /etc/sysconfig/network-scripts/ifcfg-ens3
fi

# check gateway
if grep -q "GATEWAY" /etc/sysconfig/network-scripts/ifcfg-ens3; then
  echo "Error: Gateway already set"
else
  read -p "Enter Gateway: " GATEWAY
  echo "GATEWAY=$GATEWAY" >> /etc/sysconfig/network-scripts/ifcfg-ens3
fi

# check network
if grep -q "NETWORK" /etc/sysconfig/network-scripts/ifcfg-ens3; then
  echo "Error: Network already set"
else
  read -p "Enter Network: " NETWORK
  echo "NETWORK=$NETWORK" >> /etc/sysconfig/network-scripts/ifcfg-ens3
fi

echo -e "\n"
cat /etc/sysconfig/network-scripts/ifcfg-ens3
echo -e "\nPlease double check the network config above. File is in /etc/sysconfig/network-scripts/ifcfg-ens3"
