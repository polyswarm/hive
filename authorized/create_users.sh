#! /bin/bash

for i in ./*; do
  if [ -d $i ]; then
    NAME=$(basename $i)
    if [ $? -eq 0 ]; then
      mkdir -p /home/$NAME/.ssh
      chmod -R 700 /home/$NAME/
      for k in ./$i/*; do
        echo $k >> asdf
        if [[ $k == *.pub ]]; then
          cat $k >> /home/$NAME/.ssh/authorized_keys
        fi
      done
      chsh -s /bin/true $NAME
      chown -hR $NAME:$NAME /home/$NAME/
    fi
  fi
done
cd ~