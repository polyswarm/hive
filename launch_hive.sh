#! /bin/bash

token=$(cat ./token)
key=$(cat ./key)

id=$(curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d '{"name":"hop-hive","region":"nyc3","size":"s-1vcpu-1gb","image":"ubuntu-16-04-x64","ssh_keys":['$key'],"backups":false,"ipv6":false,"user_data":null,"private_networking":true,"volumes": null,"tags":["hive"]}' "https://api.digitalocean.com/v2/droplets" | jq -r ".droplet.id")

if [ $? -ne 0 ]; then
    exit $?
fi

status=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $token" "https://api.digitalocean.com/v2/droplets/$id" | jq -r ".droplet.status")

while [ "$status" != "active" ]; do 
  echo $status
  sleep 30
  status=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $token" "https://api.digitalocean.com/v2/droplets/$id" | jq -r ".droplet.status")
done

address=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $token" "https://api.digitalocean.com/v2/droplets/$id" | jq -r ".droplet.networks.v4[1].ip_address")

if [ $? -ne 0 ]; then
    exit $?
fi

echo "Hop ID $id"
echo "Hop Private IP $address"

# Setup Docker user data
userdata="#! /bin/bash
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
iptables -A INPUT -p tcp -s $address --dport 22 -i eth1 -j ACCEPT
iptables -A INPUT -p tcp -s $address --sport 31337 -j ACCEPT
iptables -A OUTPUT -p tcp -d $address --dport 31337 -j ACCEPT
iptables -A INPUT -p tcp -s $address --sport 5001 -j ACCEPT
iptables -A OUTPUT -p tcp -d $address --dport 5001 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -I INPUT -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -P INPUT DROP
iptables -P FORWARD DROP

# Without these, docker cannot build any images
iptables -A FORWARD -j DOCKER-USER
iptables -A FORWARD -j DOCKER-ISOLATION
iptables -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -o docker0 -j DOCKER
iptables -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
iptables -A FORWARD -i docker0 -o docker0 -j ACCEPT
iptables -A DOCKER-ISOLATION -j RETURN
iptables -A DOCKER-USER -j RETURN
apt-get update
apt-get install iptables-persistent -y
apt-get install git

git clone https://github.com/polyswarm/polyswarmd.git
pushd polyswarmd
cp docker/Dockerfile ./
docker build -t local/polyswarmd .
popd"


curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d '{"name":"docker-hive","region":"nyc3","size":"s-1vcpu-1gb","image":"docker","ssh_keys":['$key'],"backups":false,"ipv6":false,"user_data":"'"$userdata"'","private_networking":true,"volumes": null,"tags":["hive"]}' "https://api.digitalocean.com/v2/droplets" 
