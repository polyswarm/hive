#! /bin/bash

configure_user() {
  user=$1
  cat >> /etc/ssh/sshd_config <<- EndOfMessage

Match User ${user}
  AllowTcpForwarding yes
  X11Forwarding no
  PermitTunnel no
  GatewayPorts no
  AllowAgentForwarding no
  PermitOpen hive.polyswarm.network:31337
EndOfMessage
}

cd /root/authorized
for i in ./*; do
  if [ -d $i ]; then
    NAME=$(basename $i)
    useradd -m $NAME
    if [ $? -eq 0 ]; then
      configure_user $NAME
      mkdir -p /home/$NAME/.ssh
      chmod -R 700 /home/$NAME/
      for k in ./$i/*; do
        if [[ $k == *.pub ]]; then
          cat $k >> /home/$NAME/.ssh/authorized_keys
        fi
      done
      chmod 600 /home/$NAME/.ssh/authorized_keys
      chsh -s /bin/false $NAME
      chown -hR $NAME:$NAME /home/$NAME/
    fi
  fi
done
service ssh restart
cd ~
