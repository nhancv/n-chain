variable "env" {}
variable "project" {}

# Network
variable "vpc_id" { default = "" }
variable "subnets_app" { type = list(string) }
variable "subnets_lb" { default = [] }

# Security group
variable "security_groups_app" { type = list(string) }
variable "security_groups_lb" { default = [] }

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

# SSL
variable "domain_zone_id" {}
variable "domain_explore" {}
variable "domain_explore_cert" {}

# Others
variable "ethernal_user" {}
variable "ethernal_password" {}
