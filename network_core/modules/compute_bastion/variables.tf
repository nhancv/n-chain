variable "env" {}
variable "project" {}

# Network
variable "subnets_app" { type = list(string) }

# Security group
variable "security_groups_app" { type = list(string) }

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
