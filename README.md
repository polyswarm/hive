# PolySwarm Hive

This project is for the easy setup of a PolySwarm test/dev network on
DigitalOcean. 

It creates two droplets, one ssh hop & one docker container that spins up, geth,
IPFS, and polyswarmd. The docker droplet has a firewall preventing access from
anywhere but the ssh hop. It only allows ssh, access to polyswarmd, and access
to IPFS.

# Prereqs

* jq `sudo apt-get install jq`
* API token for DigitalOcean
  [(Instructions)](https://www.digitalocean.com/community/tutorials/how-to-use-the-digitalocean-api-v2)
* SSH key ID from DigitalOcean
  [(Instructions)](https://developers.digitalocean.com/documentation/v2/#ssh-keys)

For ease of use, you can use the follow curl statement to get the SSH key IDs.
Make sure to substitue your token for `<token>`

```
curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer
<token>" "https://api.digitalocean.com/v2/account/keys"
```

# Launching it

If you run `./launch_hive -h` It will show the following help message.

```
usage: launch_hive.sh [-h] [-A <hop_address>] <ssh key id> <digitalocean API
token>
        options:
            -h:    Print this help message.
            -A:    Use given address when setting up docker droplet. Skips
creating ssh hop.
```

For the first time it is best to run `./launch_hive.sh <ssh> <token>`. You will
need both parts up, or the docker droplet will be useless.

After that, it is quicker if you don't need to restart the ssh hop each time,
because creating droplets takes a couple minutes.

Additionally, if you grant access to other ssh keys, you would have to configure
all of them again.

To skip creating the ssh hop again, specify the `-A` argument with the address
of the SSH hop.

# Wrapping up

Once the droplets are up, you will need to do a final step to get the hive 
and running. 

When `launch_hive.sh` finished, it printed the hop public address and docker private
address. Grab both of these. Call `publish.sh` which will push up all the geth
testnet files, & start up the docker containers. 

After a few minutes, you will want to connect. On the server will be a couple
very important files. In `/root/geth` you want to copy, `static-nodes.json.` In 
`/root/contracts` you want to copy `polyswarmd.yml.` This contains the bootnode
address for users to connect & the addresses for the PolySwarm contracts.

# Connect to docker droplet

**Enable the ssh agent**
```
eval "$(ssh-agent -s)"
```

**Add your ssh key**
```
ssh-add /path/to/key
```

**Connect ssh through the ssh hop to the docker container**
```
ssh -A -i /path/to/key root@<hop public> ssh root@<docker private>
```
