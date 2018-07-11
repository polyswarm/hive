# infrastructure-wise, PolySwarm Hive is composed of:
# 1. 1 SSH hop
# 2. 1+ sealers driving a PoA chain (geth)
# 3. 1+ bootnodes pointing to the PoA chain
# 4. 1 polyswarmd node
# 5. 1 IPFS node
# 6. 1 non-sealer geth node
#
# all communications to items 2+ must route through the SSH hop (item 1)
# items 2+ may be on the same or different instances
# let's start simple: they're all on the same instance
# later, we may want to expand to 1 instance per node
####

provider "digitalocean" {
  token = "${var.do_token}"
}

resource "digitalocean_tag" "hive-internal" {
  name = "hive-internal"
}

resource "digitalocean_tag" "hive-ssh-hop" {
  name = "hive-ssh-hop"
}

resource "digitalocean_ssh_key" "default" {
  name       = "Hive Terraform"
  public_key = "${file("${var.public_key_path}")}"
}

resource "digitalocean_droplet" "ssh-hop" {
  image    = "ubuntu-18-04-x64"
  name     = "ssh-hop-1"
  region   = "${var.region}"
  size     = "s-1vcpu-1gb"
  ssh_keys = ["${digitalocean_ssh_key.default.id}"]
  tags     = ["${digitalocean_tag.hive-ssh-hop.id}"]

  provisioner "file" {
    source      = "../authorized"
    destination = "/root/authorized"

    connection = {
      type        = "ssh"
      user        = "root"
      private_key = "${file("${var.private_key_path}")}"
      agent       = false
    }
  }

  provisioner "remote-exec" {
    # Confirm user is added before adding the key
    inline = [
      "cd /root/authorized",
      "for i in ./*; do",
      "  if [ -d $i ]; then",
      "    NAME=$(basename $i)",
      "    useradd $NAME",
      "    if [ $? -eq 0 ]; then",
      "      mkdir -p /home/$NAME/.ssh",
      "      cat $NAME/id.pub > /home/$NAME/.ssh/authorized_keys",
      "      chmod -R 700 /home/$NAME/",
      "      chown -hR $NAME:$NAME /home/$NAME/",
      "    fi",
      "  fi",
      "done",
      "cd",
    ]

    connection = {
      type        = "ssh"
      user        = "root"
      private_key = "${file("${var.private_key_path}")}"
      agent       = false
    }
  }
}

# TODO: a single droplet for everything but the SSH hop. we should decompose this.
resource "digitalocean_droplet" "meta" {
  image    = "docker"
  name     = "meta"
  region   = "${var.region}"
  size     = "s-4vcpu-8gb"
  ssh_keys = ["${digitalocean_ssh_key.default.id}"]
  tags     = ["${digitalocean_tag.hive-internal.id}"]

  provisioner "file" {
    source      = "../docker"
    destination = "/root/docker"

    connection = {
      type                = "ssh"
      user                = "root"
      private_key         = "${file("${var.private_key_path}")}"
      bastion_private_key = "${file("${var.private_key_path}")}"
      bastion_host        = "${digitalocean_droplet.ssh-hop.ipv4_address}"
      bastion_user        = "root"
      agent               = false
    }
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir /root/contracts",
      "curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose",
      "chmod +x /usr/local/bin/docker-compose",
      "pushd root",
      "docker-compose -f ./docker/docker-compose-hive.yml up -d bootnode",
      "docker-compose -f ./docker/docker-compose-hive.yml up -d",
    ]

    connection = {
      type                = "ssh"
      user                = "root"
      private_key         = "${file("${var.private_key_path}")}"
      bastion_private_key = "${file("${var.private_key_path}")}"
      bastion_host        = "${digitalocean_droplet.ssh-hop.ipv4_address}"
      bastion_user        = "root"
      agent               = false
    }
  }
}

resource "digitalocean_floating_ip" "ssh-hop" {
  droplet_id = "${digitalocean_droplet.ssh-hop.id}"
  region     = "${digitalocean_droplet.ssh-hop.region}"
}

resource "digitalocean_floating_ip" "meta" {
  droplet_id = "${digitalocean_droplet.meta.id}"
  region     = "${digitalocean_droplet.meta.region}"
}

# NOTE: effectively treat protocol and port_range as required due to bugs in DO's API
resource "digitalocean_firewall" "hive-internal" {
  # permit comms among "hive-ssh-hop" and "hive-internal" groups

  name = "hive-internal-only"

  droplet_ids = ["${digitalocean_droplet.meta.id}"]

  # permit inbound from hive-internal and hive-ssh-hop
  inbound_rule = [
    {
      protocol    = "tcp"
      port_range  = "22"
      source_tags = ["hive-internal", "hive-ssh-hop"]
    },
    {
      protocol    = "tcp"
      port_range  = "31337"
      source_tags = ["hive-internal", "hive-ssh-hop"]
    },
    {
      protocol    = "tcp"
      port_range  = "1-65535"
      source_tags = ["hive-internal"]
    },
  ]

  # permit outbound to hive-internal
  outbound_rule = [
    {
      protocol         = "tcp"
      port_range       = "1-65535"
      destination_tags = ["hive-internal"]
    },
    {
      protocol         = "udp"
      port_range       = "1-65535"
      destination_tags = ["hive-internal"]
    },
  ]
}

resource "digitalocean_firewall" "hive-ssh-hop" {
  name        = "only-ssh-in-dns-out"
  droplet_ids = ["${digitalocean_droplet.ssh-hop.id}"]

  # permit inbound SSH from *
  inbound_rule = [
    {
      protocol         = "tcp"
      port_range       = "${var.port-ssh}"
      source_addresses = ["0.0.0.0/0"]
    },
  ]

  # permit outbound DNS to * (TODO: do we need this)
  # permit outbound all to hive-internal
  outbound_rule = [
    {
      protocol              = "tcp"
      port_range            = "${var.port-dns}"
      destination_addresses = ["0.0.0.0/0"]
    },
    {
      protocol              = "udp"
      port_range            = "${var.port-dns}"
      destination_addresses = ["0.0.0.0/0"]
    },
    {
      # permit all outbound to "hive-internal" (not other ssh hops)
      protocol         = "tcp"
      port_range       = "1-65535"
      destination_tags = ["hive-internal"]
    },
    {
      protocol         = "udp"
      port_range       = "1-65535"
      destination_tags = ["hive-internal"]
    },
    {
      # permit all outbound to "hive-internal" (not other ssh hops)
      protocol              = "tcp"
      port_range            = "1-65535"
      destination_addresses = ["${digitalocean_floating_ip.meta.ip_address}"]
    },
    {
      protocol              = "udp"
      port_range            = "1-65535"
      destination_addresses = ["${digitalocean_floating_ip.meta.ip_address}"]
    },
  ]
}

resource "digitalocean_record" "gate" {
  domain = "polyswarm.network"
  type   = "A"
  name   = "gate"
  value  = "${digitalocean_floating_ip.ssh-hop.ip_address}"
}

resource "digitalocean_record" "polyswarmd" {
  domain = "polyswarm.network"
  type   = "A"
  name   = "polyswarmd"
  value  = "${digitalocean_floating_ip.meta.ip_address}"
}

output "ip-ssh-hop" {
  value = "${digitalocean_droplet.ssh-hop.ipv4_address}"
}

output "ip-meta" {
  value = "${digitalocean_droplet.meta.ipv4_address}"
}
