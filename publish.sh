#! /bin/bash

ssh_key=$1
hop_public=$2
docker_private=$3

scp -i $ssh_key docker-compose-hive.yml root@$hop_public:/root/docker-compose-hive.yml
scp -i $ssh_key -r ./geth root@$hop_public:/root/geth
ssh -tt -i $ssh_key -A root@$hop_public scp /root/docker-compose-hive.yml root@$docker_private:/root/docker-compose-hive.yml
ssh -tt -i $ssh_key -A root@$hop_public scp -r /root/geth root@$docker_private:/root/
ssh -tt -i $ssh_key -A root@$hop_public ssh -tt root@$docker_private docker-compose -f /root/docker-compose-hive.yml up -d bootnode
ssh -tt -i $ssh_key -A root@$hop_public ssh -tt root@$docker_private docker-compose -f /root/docker-compose-hive.yml up -d geth contract
