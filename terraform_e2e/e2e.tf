
terraform {
  backend "s3" {
    skip_requesting_account_id = true
    skip_credentials_validation = true
    skip_get_ec2_platforms = true
    skip_metadata_api_check = true
    region = "us-east-1"
    bucket = "hive-state"
    key = "hive/terraform.e2e.tfstate"
    endpoint = "https://nyc3.digitaloceanspaces.com"
  }
}

provider "digitalocean" {
  token = "${var.do_token}"
}

resource "digitalocean_tag" "e2e-hive-internal" {
  name = "e2e-hive-internal"
}

resource "digitalocean_tag" "e2e-hive-hop" {
  name = "e2e-hive-hop"
}

resource "digitalocean_ssh_key" "default" {
  name       = "e2e terraform"
  public_key = "${file("${var.public_key_path}")}"
}

resource "digitalocean_droplet" "e2e-ssh-hop" {
  image    = "ubuntu-18-04-x64"
  name     = "e2e-ssh-hop"
  region   = "${var.region}"
  size     = "s-1vcpu-1gb"
  ssh_keys = ["${digitalocean_ssh_key.default.id}"]
  tags     = ["${digitalocean_tag.e2e-hive-hop.id}"]

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
    script = "../scripts/create_users.sh"

    connection = {
      type        = "ssh"
      user        = "root"
      private_key = "${file("${var.private_key_path}")}"
      agent       = false
    }
  }
}

# TODO: a single droplet for everything but the SSH hop. we should decompose this.
resource "digitalocean_droplet" "e2e-meta" {
  image    = "docker"
  name     = "e2e-meta"
  region   = "${var.region}"
  size     = "s-4vcpu-8gb"
  ssh_keys = ["${digitalocean_ssh_key.default.id}"]
  tags     = ["${digitalocean_tag.e2e-hive-internal.id}"]

  provisioner "file" {
    source      = "../e2e"
    destination = "/root/docker"

    connection = {
      type                = "ssh"
      user                = "root"
      private_key         = "${file("${var.private_key_path}")}"
      bastion_private_key = "${file("${var.private_key_path}")}"
      bastion_host        = "${digitalocean_droplet.e2e-ssh-hop.ipv4_address}"
      bastion_user        = "root"
      agent               = false
    }
  }

  provisioner "file" {
    source      = "../scripts"
    destination = "/root/scripts"

    connection = {
      type                = "ssh"
      user                = "root"
      private_key         = "${file("${var.private_key_path}")}"
      bastion_private_key = "${file("${var.private_key_path}")}"
      bastion_host        = "${digitalocean_droplet.e2e-ssh-hop.ipv4_address}"
      bastion_user        = "root"
      agent               = false
    }
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir /root/contracts",
      "curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose",
      "chmod +x /usr/local/bin/docker-compose",
      "pushd /root",
      "chmod -R +x /root/scripts",
      "docker-compose -f ./docker/docker-compose-e2e.yml up -d",
    ]

    connection = {
      type                = "ssh"
      user                = "root"
      private_key         = "${file("${var.private_key_path}")}"
      bastion_private_key = "${file("${var.private_key_path}")}"
      bastion_host        = "${digitalocean_droplet.e2e-ssh-hop.ipv4_address}"
      bastion_user        = "root"
      agent               = false
    }
  }
}

# NOTE: effectively treat protocol and port_range as required due to bugs in DO's API
resource "digitalocean_firewall" "e2e-hive-internal" {
  # permit comms among "hive-ssh-hop" and "hive-internal" groups

  name = "e2e-hive-internal-only"

  droplet_ids = ["${digitalocean_droplet.e2e-meta.id}"]

  # permit inbound from hive-internal and hive-ssh-hop
  inbound_rule = [
    {
      protocol    = "tcp"
      port_range  = "22"
      source_tags = ["e2e-hive-internal", "e2e-hive-hop"]
    },
    {
      protocol    = "tcp"
      port_range  = "31337"
      source_tags = ["e2e-hive-internal", "e2e-hive-hop"]
    },
    {
      protocol    = "tcp"
      port_range  = "1-65535"
      source_tags = ["e2e-hive-internal"]
    },
  ]

  # permit outbound to hive-internal
  outbound_rule = [
    {
      protocol         = "tcp"
      port_range       = "1-65535"
      destination_tags = ["e2e-hive-internal"]
    },
    {
      protocol         = "udp"
      port_range       = "1-65535"
      destination_tags = ["e2e-hive-internal"]
    },
  ]
}

resource "digitalocean_firewall" "e2e-hive-hop" {
  name        = "e2e-only-ssh-in-dns-out"
  droplet_ids = ["${digitalocean_droplet.e2e-ssh-hop.id}"]

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
      destination_tags = ["e2e-hive-internal"]
    },
    {
      protocol         = "udp"
      port_range       = "1-65535"
      destination_tags = ["e2e-hive-internal"]
    },
    {
      # permit all outbound to "hive-internal" (not other ssh hops)
      protocol              = "tcp"
      port_range            = "1-65535"
      destination_addresses = ["${digitalocean_droplet.e2e-ssh-hop.ipv4_address}"]
    },
    {
      protocol              = "udp"
      port_range            = "1-65535"
      destination_addresses = ["${digitalocean_droplet.e2e-meta.ipv4_address}"]
    },
  ]
}

resource "digitalocean_record" "dev-gate" {
  domain = "polyswarm.network"
  type   = "A"
  name   = "dev-gate"
  value  = "${digitalocean_droplet.e2e-ssh-hop.ipv4_address}"
}

resource "digitalocean_record" "dev-hive" {
  domain = "polyswarm.network"
  type   = "A"
  name   = "dev-hive"
  value  = "${digitalocean_droplet.e2e-meta.ipv4_address}"
}

output "ip-dev-hop" {
  value = "${digitalocean_droplet.e2e-ssh-hop.ipv4_address}"
}

output "ip-dev-meta" {
  value = "${digitalocean_droplet.e2e-meta.ipv4_address}"
}
