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
	name 		= "Hive Terraform"
	public_key 	= "${file("${var.public_key_path}")}"
}


resource "digitalocean_droplet" "ssh-hop" {
	image 			= "ubuntu-18-04-x64"
	name 			= "ssh-hop-1"
	region 			= "sfo2"
	size 			= "1gb"
	#backups 		= "false"
	#monitoring 		= "false"
	#ipv6 			= "false"
	#private_networking 	= "false"
	ssh_keys 		= ["${digitalocean_ssh_key.default.id}"]
	#resize_disk 		= "true"
	tags 			= ["${digitalocean_tag.hive-ssh-hop.id}"]
	#user_data 		= ""
	#volume_ids 		= ""
}

# TODO: a single droplet for everything but the SSH hop. we should decompose this.
resource "digitalocean_droplet" "meta" {
	image			= "ubuntu-18-04-x64"
	name			= "meta"
	region			= "sfo2"
	size			= "1gb"
	ssh_keys		= ["${digitalocean_ssh_key.default.id}"]
	tags			= ["${digitalocean_tag.hive-internal.id}"]

	provisioner "remote-exec" {
		inline = [
			"curl -fsSL get.docker.com -o get-docker.sh",
			"chmod +x get-docker.sh" ,
			"sh get-docker.sh",
		]
		connection = {
			type = "ssh"
			user = "root"
			private_key = "${file("${var.private_key_path}")}"
		}
	}

}

resource "digitalocean_firewall" "hive-internal" {
	# permit comms among "hive-ssh-hop" and "hive-internal" groups
	# TODO: lock down protocols and ports

	name		= "hive-only"
	droplet_ids	= [] # TODO
	
	inbound_rule = [
		{
			protocol		= "tcp" # NOTE: protocol is required if source_tags is specified due to a bug in DO's API
			port_range		= "all"
			source_tags 		= ["hive-internal", "hive-ssh-hop"]
		},
	]

	outbound_rule = [
		{
			protocol		= "tcp" # NOTE: protocol is required if destination_tags is specified due to a bug in DO's API
			port_range		= "all" 
			destination_tags 	= ["hive-internal", "hive-ssh-hop"]
		},
	]
}


/*
resource "digitalocean_firewall" "hive-ssh-hop" {
	# permit inbound to 22 on hop
	# permit outbound DNS to all (TODO: do we need this?)
 
	name 		= "only-ssh-in-dns-out"
	droplet_ids 	= ["${digitalocean_droplet.ssh-hop.id}"]
	
	inbound_rule = [
		{	
			protocol		= "tcp"
			#port_range		= "${var.port-ssh}"
			port_range		= "22"
			source_addresses 	= ["0.0.0.0/0"]
		},

		# permit all inbound from "hive-internal" (not other ssh hops)
		# TODO: check this
		{
			source_tags		= ["hive-internal"]
		},
	]

	outbound_rule = [
		{
			protocol		= "tcp"
			#port_range		= "${var.port-dns}"
			port_range		= "53"
			destination_addresses	= ["0.0.0.0/0"]
		},
		{
			protocol		= "udp"
			#port_range		= "${var.port-dns}"
			port_range		= "53"
			destination_addresses	= ["0.0.0.0/0"]
		},

		# permit all outbound to "hive-internal" (not other ssh hops)
		# TODO: check this
		{
			destination_tags	= ["hive-internal"]
		},
	]
}
*/

resource "digitalocean_floating_ip" "ssh-hop" {
	droplet_id = "${digitalocean_droplet.ssh-hop.id}"
	region = "${digitalocean_droplet.ssh-hop.region}"
}

output "ip-ssh-hop" {
	value = "${digitalocean_floating_ip.ssh-hop.ip_address}"
} 

output "ip-meta" {
        value = "${digitalocean_droplet.meta.ipv4_address}"
}

