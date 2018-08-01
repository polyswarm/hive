variable "do_token" {}

variable "port-ssh" {
  default = "22"
}

variable "aws_secret_key" {}

variable "aws_access_key" {}

variable "port-dns" {
  default = "53"
}

variable "public_key_path" {
  default = "/home/user/.ssh/id.pub"
}

variable "private_key_path" {
  default = "/home/user/.ssh/id"
}

variable "region" {}
