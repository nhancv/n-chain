variable "env" {}
variable "project" {}

# Network
variable "vpc_id" {}
variable "subnets" {}

# Security group
variable "security_groups" { type = list(string) }

# SSL
variable "domain_zone_id" {}
variable "domain_rpc" {}
variable "domain_rpc_cert" {}
