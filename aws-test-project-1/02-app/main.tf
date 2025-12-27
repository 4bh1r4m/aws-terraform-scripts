

#SSH Key Generation
resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.generated.private_key_pem
  filename        = "${path.module}/private_key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "web-tier-key"
  public_key = tls_private_key.generated.public_key_openssh
}

#Modules

module "networking" {
  source       = "./modules/networking"
  aws_region   = var.aws_region
  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
}

module "presentation" {
  source          = "./modules/presentation"
  vpc_id          = module.networking.vpc_id
  public_subnets  = module.networking.public_subnets
  ami_id          = var.ami_id
  key_name        = aws_key_pair.deployer_key.key_name
  ssh_private_key = tls_private_key.generated.private_key_pem
  
  # Pass IPs from App Tier
  app_tier_ip_a   = module.application.private_ip_a
  app_tier_ip_b   = module.application.private_ip_b
  
  # DNS Vars
  domain_name     = var.domain_name
  project_name    = var.project_name
  alb_zone_id     = var.alb_zone_id[var.aws_region]
}

module "application" {
  source             = "./modules/application"
  vpc_id             = module.networking.vpc_id
  private_subnets    = module.networking.app_subnets
  ami_id             = var.ami_id
  key_name           = aws_key_pair.deployer_key.key_name
  web_tier_sg_id     = module.presentation.web_tier_sg_id
  
  # DB Info
  rds_endpoint       = module.database.rds_endpoint
  db_master_user     = var.db_username
  db_master_password = var.db_password

  # Explicitly wait for Networking (NAT Gateway) to be ready
  depends_on         = [module.networking]
}

module "database" {
  source         = "./modules/database"
  vpc_id         = module.networking.vpc_id
  db_subnets     = module.networking.db_subnets
  aws_region     = var.aws_region
  app_tier_sg_id = module.application.app_tier_sg_id
  
  db_username    = var.db_username
  db_password    = var.db_password
}