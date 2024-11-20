/**
TERRAFORM, INFRASTRUCTURE AS CODE

RESOURCE naming template:
{env}-{project}-{module}
WHERE
env: [testnet,mainnet]
======================================================
DEPLOY
terraform init
terraform plan
terraform apply [-auto-approve]

VIEW STATE
terraform show
-> Read instance input, public_ip

DESTROY
terraform plan -destroy
terraform apply -destroy [-auto-approve]
**/

terraform {
  # Defines AWS providers
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}

provider "aws" {
  region     = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
}

module "rpc_acm_cert" {
  source         = "./modules/acm_cert"
  domain_zone_id = var.domain_zone_id
  domain_name    = var.domain_rpc
}

module "stats_acm_cert" {
  source         = "./modules/acm_cert"
  domain_zone_id = var.domain_zone_id
  domain_name    = var.domain_stats_https
}

module "networking" {
  env                = var.env
  project            = var.project
  source             = "./modules/networking"
  cidr_vpc           = var.cidr_vpc
  availability_zones = var.availability_zones
  cidrs_public       = var.cidrs_public
  cidrs_compute      = var.cidrs_compute
  cidrs_lb_p2p       = var.cidrs_lb_p2p
  cidrs_stats        = var.cidrs_stats
}

module "security_group" {
  env       = var.env
  project   = var.project
  source    = "./modules/security_group"
  cidr_vpc  = var.cidr_vpc
  vpc_id    = module.networking.vpc_id
  access_ip = var.access_ip

  depends_on = [module.networking]
}

resource "aws_key_pair" "bastion" {
  key_name   = "${var.env}-${var.project}-bastion"
  public_key = var.public_key_pair_bastion
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_key_pair" "project" {
  key_name   = "${var.env}-${var.project}-project"
  public_key = var.public_key_pair_project
  lifecycle {
    create_before_destroy = true
  }
}

module "compute_bastion" {
  env                 = var.env
  project             = var.project
  source              = "./modules/compute_bastion"
  subnets_app         = tolist(module.networking.subnet_public)
  security_groups_app = [module.security_group.sg_ssh_public]
  access_key_id       = aws_key_pair.bastion.id
  instance_conf       = var.instance_type_bastion
}

module "compute_stats" {
  depends_on = [module.stats_acm_cert.certificate_validation]

  env                 = var.env
  project             = var.project
  source              = "./modules/compute_stats"
  vpc_id              = module.networking.vpc_id
  subnets_app         = tolist(module.networking.subnet_node_stats)
  subnets_lb          = tolist(module.networking.subnet_public)
  security_groups_app = [
    module.security_group.sg_ssh_private,
    module.security_group.sg_node_stats,
  ]
  security_groups_lb  = [
    module.security_group.sg_http_public,
  ]
  access_key_id       = aws_key_pair.project.id
  instance_conf       = var.instance_type_stats
  ethstats_secret     = var.ethstats_secret
  domain_zone_id      = var.domain_zone_id
  domain_stats_https  = var.domain_stats_https
  domain_stats_cert   = module.stats_acm_cert.cert
  domain_stats_push   = var.domain_stats_push

}

module "alb_rpc" {
  env             = var.env
  project         = var.project
  source          = "modules/alb_public_rpc"
  vpc_id          = module.networking.vpc_id
  subnets         = tolist(module.networking.subnet_public)
  security_groups = [module.security_group.sg_http_public]
  domain_zone_id  = var.domain_zone_id
  domain_rpc      = var.domain_rpc
  domain_rpc_cert = module.rpc_acm_cert.cert
}

module "compute_nodes" {
  depends_on = [module.rpc_acm_cert.certificate_validation, module.alb_rpc, module.compute_stats]

  count                   = length(var.domain_nodes)
  node_id                 = count.index + 1
  env                     = var.env
  project                 = var.project
  source                  = "./modules/compute_node"
  vpc_id                  = module.networking.vpc_id
  subnet_node_compute     = tolist(module.networking.subnet_node_core)
  subnet_node_lb_p2p      = tolist(module.networking.subnet_node_lb_p2p)
  security_groups_private = [
    module.security_group.sg_ssh_private,
    module.security_group.sg_node_p2p,
    module.security_group.sg_node_rpc,
  ]
  security_groups_public  = [
    module.security_group.sg_http_public,
  ]

  access_key_id        = aws_key_pair.project.id
  instance_conf        = var.instance_type_node
  ethstats_secret      = var.ethstats_secret
  ethstats_push        = var.domain_stats_push
  encrypt_key          = var.encrypt_key
  rpc_target_group_arn = module.alb_rpc.target_group
  domain_zone_id       = var.domain_zone_id
  domain_node          = var.domain_nodes[count.index]
}

module "sns" {
  env          = var.env
  project      = var.project
  source       = "./modules/sns"
  sns_endpoint = var.sns_endpoint
  group_names  = concat(module.compute_nodes[*].compute_name, [module.compute_stats.compute_name])
}
