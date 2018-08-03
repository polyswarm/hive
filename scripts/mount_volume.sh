#! /bin/bash

name=$1

while [ ! -e /dev/sda ]; do echo "SDA does not exist yet"; sleep 1; done

if [ ! -L /dev/disk/by-id/scsi-0DO_Volume_$name-part1 ]; then
    echo "Partitioning."
    parted /dev/disk/by-id/scsi-0DO_Volume_$name mklabel gpt -s
    parted -a opt /dev/disk/by-id/scsi-0DO_Volume_$name mkpart primary 0% 100% -s
    echo "Waiting for probe to finish"
    partprobe
    #sleep 2
    # I know we should wait for the task to complete, but parted is async & generates the files immediately, despite not being ready
    echo "Formatting."
    mkfs.ext4 -F /dev/disk/by-id/scsi-0DO_Volume_$name-part1
fi

mkdir -p /mnt/$name
mount -o defaults,discard /dev/disk/by-id/scsi-0DO_Volume_$name-part1 /mnt/$name/

echo /dev/disk/by-id/scsi-0DO_Volume_$name-part1 /mnt/$name ext4 defaults,nofail,discard 0 0 > /etc/fstab

echo "Creating docker volumes."
cd /mnt/$name
mkdir ./ipfs-export ./ipfs-data ./certs ./chain ./contracts

echo "Starting compose."
cd /root
docker-compose -f ./docker/docker-compose-hive.yml up -d
