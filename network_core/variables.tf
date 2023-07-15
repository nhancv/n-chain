variable "env" { default = "testnet" }
variable "project" { default = "nchaincore" }

variable "cidr_vpc" {
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b"]
}

# Public: Bastion, NAT Gateway
variable "cidrs_public" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

# Private: Core nodes
variable "cidrs_compute" {
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

# Private: P2P LB for Enode
variable "cidrs_lb_p2p" {
  default = ["10.0.5.0/24", "10.0.6.0/24"]
}

# Private: Stats nodes
variable "cidrs_stats" {
  default = ["10.0.7.0/24", "10.0.8.0/24"]
}

# Initial ip access to bastion host
variable "access_ip" {
  default = "0.0.0.0/0"
}

# Instance types
variable "instance_type_bastion" {
  default = {
    type : "t3.small",
    min_size : 1,
    max_size : 1,
    desired_capacity : 1
  }
}

variable "instance_type_node" {
  default = {
    type : "t3.large",
    min_size : 1,
    max_size : 1,
    desired_capacity : 1
  }
}

variable "instance_type_stats" {
  default = {
    type : "t3.medium",
    min_size : 1,
    max_size : 1,
    desired_capacity : 1
  }
}

# Ethstats Server Secret
variable "ethstats_secret" {
  type    = string
  default = "secret"
}
variable "encrypt_key" {
  type    = string
  default = "secret"
}

# SNS Emails
variable "sns_endpoint" { default = "me@nhancv.com" }

### AWS CREDENTIALS CONFIG ON CLOUD ###
variable "AWS_REGION" { default = "us-east-1" }
variable "AWS_ACCESS_KEY" { sensitive = true }
variable "AWS_SECRET_KEY" { sensitive = true }

variable "public_key_pair_bastion" { sensitive = true }
variable "public_key_pair_project" { sensitive = true }
variable "domain_zone_id" {}
variable "domain_rpc" { default = "rpc.nhancv.com" }
variable "domain_nodes" {
  default = ["1.node.nhancv.com", "2.node.nhancv.com", "3.node.nhancv.com", "4.node.nhancv.com"]
}
variable "domain_stats_https" { default = "stats.nhancv.com" }
variable "domain_stats_push" { default = "push.stats.nhancv.com" }
