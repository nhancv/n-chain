variable "env" { default = "testnet" }
variable "project" { default = "nchaintools" }

variable "cidr_vpc" {
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b"]
}

# Bastion, NAT Gateway
variable "cidrs_public" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

# Host all thing related http/s
variable "cidrs_project" {
  default = ["10.0.3.0/24", "10.0.4.0/24"]
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

variable "instance_type_project" {
  default = {
    type : "t3.large",
    min_size : 1,
    max_size : 1,
    desired_capacity : 1
  }
}

# SNS Emails
variable "sns_endpoint" { default = "nhancv@google.com" }

### AWS CREDENTIALS CONFIG ON CLOUD ###
variable "AWS_REGION" { default = "us-east-1" }
variable "AWS_ACCESS_KEY" { sensitive = true }
variable "AWS_SECRET_KEY" { sensitive = true }

variable "public_key_pair_bastion" { sensitive = true }
variable "public_key_pair_project" { sensitive = true }
variable "domain_zone_id" {}
variable "domain_explore" { default = "scan.nhancv.com" }
variable "ethernal_user" { default = "me@nhancv.com" }
variable "ethernal_password" { default = "secret" }
variable "domain_blockscout" { default = "blockscout.nhancv.com" }
variable "blockscout_rpc" { default = "https://rpc.nhancv.com" }
variable "blockscout_chainid" { default = "1584821" }
