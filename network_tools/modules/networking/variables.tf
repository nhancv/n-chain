variable "env" {}
variable "project" {}

variable "cidr_vpc" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

# Bastion, NAT Gateway
variable "cidrs_public" {
  type = list(any)
}

# Host all thing related http/s
variable "cidrs_project" {
  type = list(any)
}
