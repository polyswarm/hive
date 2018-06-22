#! /bin/bash

token=$(<token)
key=$(<key)
path=$(<path)
compose=$(<docker-compose-priv-testnet.yml)

echo "Building SSH Hop droplet"
id=$(curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d '{"name":"hop-hive","region":"nyc3","size":"s-1vcpu-1gb","image":"ubuntu-16-04-x64","ssh_keys":['$key'],"backups":false,"ipv6":false,"user_data":null,"private_networking":true,"volumes": null,"tags":["hive"]}' "https://api.digitalocean.com/v2/droplets" 2>/dev/null | jq -r ".droplet.id")

if [ $? -ne 0 ]; then
    exit $?
fi

status='waiting'

echo "Waiting for SSH Hop to finish activating"
while [ "$status" != "active" ]; do 
  sleep 60
  status=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $token" "https://api.digitalocean.com/v2/droplets/$id" 2>/dev/null | jq -r ".droplet.status")
done

echo "Retrieving SSH Hop private address"
address=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $token" "https://api.digitalocean.com/v2/droplets/$id" 2>/dev/null | jq -r ".droplet.networks.v4[1].ip_address")
hop=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $token" "https://api.digitalocean.com/v2/droplets/$id" 2>/dev/null | jq -r ".droplet.networks.v4[0].ip_address")

if [ $? -ne 0 ]; then
    exit $?
fi

# Setup Docker user data
userdata="#! /bin/bash
# Add docker rules
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F

service docker restart

# Allow SSH hop to access via ssh
iptables -A INPUT -i eth1 -p tcp -s $address --dport 22 -j ACCEPT

# Allow access to dockerd ports
iptables -A INPUT -p tcp --dport 2735 -j ACCEPT
iptables -A INPUT -p tcp --dport 2736 -j ACCEPT

# Allow SSH hop access to polyswarmd
iptables -A INPUT -i eth1 -p tcp -s $address --dport 31337 -j ACCEPT
iptables -A OUTPUT -o eth1 -p tcp -d $address --sport 31337 -j ACCEPT

# Allow ssh hop access to ipfs
iptables -A INPUT -i eth1 -p tcp -s $address --dport 4001 -j ACCEPT
iptables -A OUTPUT -o eth1 -p tcp -d $address --sport 4001 -j ACCEPT

# Block all ports to docker containers from outside
iptables -A INPUT -i eth0 -p tcp --dport 31337 -j DROP
iptables -A INPUT -i eth0 -p tcp --dport 8545 -j DROP
iptables -A INPUT -i eth0 -p tcp --dport 4001 -j DROP
iptables -A INPUT -i eth0 -p tcp --dport 30303 -j DROP
iptables -A INPUT -i eth0 -p tcp --dport 7545 -j DROP

# Allow access via loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow incoming connections that we initiated already
iptables -I INPUT -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Reset policies to drop input & forward
iptables -P INPUT DROP 
iptables -P FORWARD DROP

apt-get update
apt-get install iptables-persistent build-essential -y
curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo \\\"$compose\\\" > docker-compose-priv-testnet.yml

docker-compose -f /docker-compose-priv-testnet.yml up -d
"

echo "Creating Docker droplet"
id=$(curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d '{"name":"docker-hive","region":"nyc3","size":"s-4vcpu-8gb","image":"docker","ssh_keys":['$key'],"backups":false,"ipv6":false,"user_data":"'"$userdata"'","private_networking":true,"volumes": null,"tags":["hive"]}' "https://api.digitalocean.com/v2/droplets" 2>/dev/null | jq -r ".droplet.id")

if [ $? -ne 0 ]; then
    exit $?
fi

status='waiting'

echo "Waiting for Docker to finish activating"
while [ "$status" != "active" ]; do 
  sleep 60
  status=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $token" "https://api.digitalocean.com/v2/droplets/$id" 2>/dev/null | jq -r ".droplet.status")
done

if [ $? -ne 0 ]; then
    exit $?
fi

private=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $token" "https://api.digitalocean.com/v2/droplets/$id" 2>/dev/null | jq -r ".droplet.networks.v4[1].ip_address")

if [ $? -ne 0 ]; then
    exit $?
fi

echo "Hop ID $id"
echo "Hop Private IP $address"
echo "Hop Public IP $hop"
echo "Docker ID $id"
echo "Docker Private IP $private"
