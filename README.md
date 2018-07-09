# PolySwarm Hive

Easy stand up & management of DigitalOcean droplets for a PolySwarm testnet.`

## Prerequisites

* API token for DigitalOcean
  [(Instructions)](https://www.digitalocean.com/community/tutorials/how-to-use-the-digitalocean-api-v2)
* Unencrypted SSH Key in `/home/user/.ssh/id`. (This is a terraform requirement: Use `ssh-keygen` to create it. Don't enter a password)
* Install Terraform [(Instructions)](https://www.terraform.io/intro/getting-started/install.html)

## Launch it

Run `./launch_hive.sh`.

It will prompt for a token, paste the one you grabed from DigitalOcean.

Next, it will prompt for a region. You can find a list of regions on the right hand side [here](https://status.digitalocean.com/).

After that, it should run to completion.

## Re-create the meta droplet.

Sometimes you will want to recreate the meta droplet, without changing the ssh hop. This is easy to do. Just delete the droplet in the digital ocean UI, and run the following command.

```bash
pushd terraform && terraform state rm digitalocean_droplet.meta && popd
```

Run `./launch_hive.sh` again and it will rebuild the droplet for you.

## Connect to docker droplet

### Enable the ssh agent

```bash
eval "$(ssh-agent -s)"
```

### Add your ssh key

```bash
ssh-add /home/user/.ssh/id
```

### Connect ssh through the ssh hop to the docker container

```bash
ssh -A -i /home/user/.ssh/id root@gate.polyswarm.network ssh root@<docker_public_ip>
```

## Timeouts

Sometimes, when building the hive the file provisioner will fail. This is a problem that arises within terraform using a bastion host (as we are). Just run `./launch_hive.sh` with the same region again, and it should succeed.
