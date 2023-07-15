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

module "explore_acm_cert" {
  source         = "./modules/acm_cert"
  domain_zone_id = var.domain_zone_id
  domain_name    = var.domain_explore
}

module "networking" {
  env                = var.env
  project            = var.project
  source             = "./modules/networking"
  cidr_vpc           = var.cidr_vpc
  availability_zones = var.availability_zones
  cidrs_public       = var.cidrs_public
  cidrs_project      = var.cidrs_project
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

module "compute_ethernal" {
  depends_on = [module.explore_acm_cert.certificate_validation]

  env                 = var.env
  project             = var.project
  source              = "./modules/compute_ethernal"
  vpc_id              = module.networking.vpc_id
  subnets_app         = tolist(module.networking.subnet_project)
  subnets_lb          = tolist(module.networking.subnet_public)
  security_groups_app = [
    module.security_group.sg_ssh_private,
    module.security_group.sg_project_private,
  ]
  security_groups_lb  = [
    module.security_group.sg_http_public,
  ]
  access_key_id       = aws_key_pair.project.id
  instance_conf       = var.instance_type_project
  domain_zone_id      = var.domain_zone_id
  domain_explore      = var.domain_explore
  domain_explore_cert = module.explore_acm_cert.cert
  ethernal_user       = var.ethernal_user
  ethernal_password   = var.ethernal_password
}

module "sns" {
  env          = var.env
  project      = var.project
  source       = "./modules/sns"
  sns_endpoint = var.sns_endpoint
  group_names  = [
    module.compute_ethernal.compute_name,
  ]
}
