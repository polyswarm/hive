variable "do_token" {}

variable "port-ssh" {
	default = "22"
}

variable "port-dns" {
	default = "53"
}

variable "public_key_path" {
	default = "/home/user/.ssh/id.pub"
}

variable "private_key_path" {
	default = "/home/user/.ssh/id"
}
