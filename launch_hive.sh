#! /bin/bash

read_args() {
    while getopts "hA:" opt; do
        case $opt in
            h)
                echo "
usage: $0 [-h] [-A <hop_address>] <ssh key id> <digitalocean API token>
    options:
        -h:    Print this help message.
        -A:    Use given address when setting up docker droplet. Skips creating ssh hop.
"
                exit 0
                ;;
            A)
                hop_private=$OPTARG
                ;;
            \?)
                echo "Invalid option -$OPTARG" >&2
                exit 1
                ;;
            :)
                echo "Option -$OPTARG requires argument" >&2
                exit 1
                ;;
        esac
    done
        shift $((OPTIND-1))

        # Load User values
        key=$1
        token=$2

        # Exit if key/token not specified
        if [ -z "$key" ]; then
            echo "No ssh key specified."
            exit 1
        fi

        if [ -z "$token" ]; then
            echo "No token specified."
            exit 1
        fi
    }

    create_docker_user_data() {
        # $1 is address

        local compose=$(<docker-compose-priv-testnet.yml)
        local dockerfile=$(<Dockerfile)
        local enode=$(<enode.sh)
        # Setup Docker user data
        userdata="#! /bin/bash
        # Add docker rules
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -F

        # Re-add Docker iptables rules
        service docker restart

        # Allow SSH hop to access via ssh
        iptables -A INPUT -i eth1 -p tcp -s $1 --dport 22 -j ACCEPT

        # Allow access to dockerd ports
        iptables -A INPUT -p tcp --dport 2735 -j ACCEPT
        iptables -A INPUT -p tcp --dport 2736 -j ACCEPT

        # Allow SSH hop access to geth
        iptables -A INPUT -i eth1 -p tcp -s $1 --dport 30303 -j ACCEPT
        iptables -A OUTPUT -o eth1 -p tcp -d $1 --sport 30303 -j ACCEPT

        # Block all ports to docker containers from outside
        iptables -A INPUT -i eth0 -p udp --dport 30301 -j DROP
        iptables -A INPUT -i eth0 -p tcp --dport 8545 -j DROP
        iptables -A INPUT -i eth0 -p tcp --dport 30303 -j DROP

        # Allow access via loopback
        iptables -A INPUT -i lo -j ACCEPT

        # Allow incoming connections that we initiated already
        iptables -I INPUT -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT

        # Reset policies to drop input & forward
        iptables -P INPUT DROP
        iptables -P FORWARD DROP

        apt-get update
        apt-get install jq iptables-persistent build-essential -y
        curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-\`uname -s\`-\`uname -m\` -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose

        echo \\\"$compose\\\" > ~/docker-compose-priv-testnet.yml
        echo \\\"$dockerfile\\\" > ~/Dockerfile
        echo \\\"$enode\\\" > ~/enode.sh

        # Create output file for Contract addrs
        mkdir ~/docker

        docker-compose -f ~/docker-compose-priv-testnet.yml up -d"
}

create_server() {
    # $1 is name
    # $2 is size
    # $3 is image
    # $4 is user_data

    if [ "$4" = "null" ]; then
        droplet=$(curl -v -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d '{"name":"'"$1"'","region":"nyc3","size":"'"$2"'","image":"'"$3"'","ssh_keys":['$key'],"backups":false,"ipv6":false,"user_data": null,"private_networking":true,"volumes": null,"tags":["hive"]}' "https://api.digitalocean.com/v2/droplets" 2>/dev/null)
    else
        droplet=$(curl -v -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d '{"name":"'"$1"'","region":"nyc3","size":"'"$2"'","image":"'"$3"'","ssh_keys":['$key'],"backups":false,"ipv6":false,"user_data":"'"$4"'","private_networking":true,"volumes": null,"tags":["hive"]}' "https://api.digitalocean.com/v2/droplets" 2>/dev/null)
    fi

    id=$(echo "$droplet" | jq -r ".droplet.id")

    if [ "$id" = "null" ]; then
        echo "Cannot start a droplet. Are your key/token valid?"
        echo $droplet
        exit 1
    fi

    status='waiting'
    echo "Waiting for $1:$id to finish activating"
    while [ "$status" != "active" ]; do 
      sleep 60
      status=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $token" "https://api.digitalocean.com/v2/droplets/$id" 2>/dev/null | jq -r ".droplet.status")
    done

    get_addrs "$1" $id
}

get_addrs() {
    # $1 is name
    # $2 is id 
    echo "Retrieving $1 addresses"
    local droplet=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $token" "https://api.digitalocean.com/v2/droplets/$2" 2>/dev/null)
 
    public=$(echo "$droplet" | jq -r ".droplet.networks.v4[0].ip_address")
    private=$(echo "$droplet" | jq -r ".droplet.networks.v4[1].ip_address")

}

# Read options & arguments
read_args $@

if [ -z "$hop_private" ]; then
    echo "Building SSH Hop droplet"
    create_server hop-hive s-1vcpu-1gb ubuntu-16-04-x64 null
    hop_id=$id
    hop_public=$public
    hop_private=$private
else
    echo "SSH Hop already built. Using $hop_private"
fi

echo "Building Docker droplet"
create_docker_user_data $hop_private
create_server docker-hive s-4vcpu-8gb docker "$userdata"

docker_id=$id
docker_public=$public
docker_private=$private

if [ ! -z "$hop_public" ]; then
    echo "Hop ID $hop_id"
    echo "Hop Public IP $hop_public"
fi
echo "Hop Private IP $hop_private"
echo "Docker ID $docker_id"
echo "Docker Public IP $docker_public"
echo "Docker Private IP $docker_private"
