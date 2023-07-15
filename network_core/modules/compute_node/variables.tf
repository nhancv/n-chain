variable "env" {}
variable "project" {}

# Network
variable "vpc_id" { default = "" }
variable "subnet_node_compute" { type = list(string) }
variable "subnet_node_lb_p2p" { default = [] }

# Security group
variable "security_groups_private" { type = list(string) }
variable "security_groups_public" { default = [] }

# Instance key pair
variable "access_key_id" {}

# Instance type
variable "instance_conf" {
  type = object({
    type : string
    min_size : number
    max_size : number
    desired_capacity : number
  })
}
variable "node_id" {}

# RPC ALB
variable "rpc_target_group_arn" {}

# SSL
variable "domain_zone_id" {}
variable "domain_node" {}

# Secret
variable "encrypt_key" {}
variable "ethstats_secret" {}
variable "ethstats_push" {}
