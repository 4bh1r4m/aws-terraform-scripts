/* 
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
 */
 
#find the zone I already created named pointbreak.space
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

#create Vpc
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = "dev"
    project     = "${var.project_name}"
  }
}
#internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-subnet-public1-${var.aws_region}a"
  }
}
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.16.0/20"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-subnet-public2-${var.aws_region}b" }
}

#app tier private subnets
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "${var.project_name}-subnet-private1-${var.aws_region}a"
  }
}
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-subnet-private2-${var.aws_region}b"
  }
}

#db and web tier private subnets
resource "aws_subnet" "private_3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.160.0/20"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-subnet-private3-${var.aws_region}a"
  }
}

resource "aws_subnet" "private_4" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.176.0/20"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-subnet-private4-${var.aws_region}b"
  }
}

#nat gateway setups
resource "aws_eip" "nat" {
  domain = "vpc"
}
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

#public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "${var.project_name}-public-rt"
  }
  depends_on = [aws_internet_gateway.gw]
}
#private routetable
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = {
    Name = "${var.project_name}-rt-private"
  }
}
#assocation of public subnet with public route table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_3" {
  subnet_id      = aws_subnet.private_3.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_4" {
  subnet_id      = aws_subnet.private_4.id
  route_table_id = aws_route_table.private.id
}

#Generate the private key
resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#Save the private key to a local file
resource "local_file" "private_key_pem" {
  content         = tls_private_key.generated.private_key_pem
  filename        = "${path.module}/private_key.pem"
  file_permission = "0400"
}

/* 
#key pair upload to aws
resource "aws_key_pair" "deployer_key" {
  key_name   = "web-tier-key"
  public_key = file("${path.module}/ssh-keys/ed25519.pub")
}
*/

#Use generated public key instead of file
resource "aws_key_pair" "deployer_key" {
  key_name   = "web-tier-key"
  public_key = tls_private_key.generated.public_key_openssh
}

#security group for web tier
resource "aws_security_group" "web_tier_sg" {
  name        = "web-tier-sg"
  description = "Allow HTTP form alb sg and SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from alb sg"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]  #remove this to allow only from alb sg
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_tier_sg"
  }
}

#instance creation for the presentation tier public subnet 1a and 1b
resource "aws_instance" "presentation_tier_instance_a" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.web_tier_sg.id]
  key_name                    = aws_key_pair.deployer_key.key_name
  associate_public_ip_address = true

  #Wait for App Tier to be ready so we have its IP
  depends_on = [aws_instance.application_tier_instance_a]

  tags = {
    Name = "presentation-tier-a"
  }
  user_data = templatefile("${path.module}/web-install.sh", {
    # Pass the App Tier private IP to the web tier for Nginx reverse proxy
    app_tier_ip     = aws_instance.application_tier_instance_a.private_ip
    
    #Pass the SSH key content for your jump host capability
    #ssh_private_key = file("${path.module}/ssh-keys/ed25519")

    ssh_private_key = tls_private_key.generated.private_key_pem
  })
  user_data_replace_on_change = true
}

resource "aws_instance" "presentation_tier_instance_b" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_2.id
  vpc_security_group_ids      = [aws_security_group.web_tier_sg.id]
  key_name                    = aws_key_pair.deployer_key.key_name
  associate_public_ip_address = true

    #Wait for App Tier to be ready so we have its IP
  depends_on = [aws_instance.application_tier_instance_b]

  tags = {
    Name = "presentation-tier-b"
  }

  user_data = templatefile("${path.module}/web-install.sh", {
    # Pass the App Tier private IP to the web tier for Nginx reverse proxy
    app_tier_ip     = aws_instance.application_tier_instance_b.private_ip
    
    #ssh_private_key = file("${path.module}/ssh-keys/ed25519")
    #Inject generated private key directly
    ssh_private_key = tls_private_key.generated.private_key_pem
  })
  user_data_replace_on_change = true
}

resource "aws_security_group" "app_tier_sg" {
  name        = "app-tier-sg"
  description = "Allow traffic from web tier sg, ssh and 3200"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "custom tcp 3200 from web tier sg"
    from_port       = 3200
    to_port         = 3200
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tier_sg.id]
  }
  ingress {
    description     = "SSH from anywhere"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tier_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #allow outbound traffic from nat gateway
  }

  tags = {
    Name = "app_tier_sg"
  }

}

#instance creation for the application tier private subnet 1a and 1b
resource "aws_instance" "application_tier_instance_a" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_1.id #private subnet 1A
  vpc_security_group_ids = [aws_security_group.app_tier_sg.id]
  key_name               = aws_key_pair.deployer_key.key_name
  depends_on             = [aws_nat_gateway.main]

  tags = {
    Name = "application-tier-a"
  }
  user_data = templatefile("${path.module}/app-install.sh", {
    rds_endpoint = aws_db_instance.rds_db.address
    db_name  = "react_node_app"
    db_username        = "appuser"
    db_password        = "appuser123#"
    db_master_user     = var.db_username
    db_master_password = var.db_password
    run_db_init        = "true"
  })
}

resource "aws_instance" "application_tier_instance_b" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_2.id #private subnet 1B
  vpc_security_group_ids = [aws_security_group.app_tier_sg.id]
  key_name               = aws_key_pair.deployer_key.key_name
  depends_on             = [aws_nat_gateway.main]

  tags = {
    Name = "application-tier-b"
  }
  user_data = templatefile("${path.module}/app-install.sh", {
    rds_endpoint       = aws_db_instance.rds_db.address
    db_name            = "react_node_app"
    db_username        = "appuser"
    db_password        = "appuser123#"
    db_master_user     = var.db_username
    db_master_password = var.db_password
    run_db_init        = "false"
  })
}

#ALB security group
resource "aws_security_group" "alb_sg" {
  name        = "application-load-balancer-sg"
  description = "Allow HTTP inbound traffic to ALB"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "alb_sg"
  }
}

#aws target group
resource "aws_lb_target_group" "three_tier_tg" {
  name        = "3-tier-target-gp"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name = "app-tg"
  }
}
#target group attachments instance A and b in public subnets 
resource "aws_lb_target_group_attachment" "presentation_a" {
  target_group_arn = aws_lb_target_group.three_tier_tg.arn
  target_id        = aws_instance.presentation_tier_instance_a.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "presentation_b" {
  target_group_arn = aws_lb_target_group.three_tier_tg.arn
  target_id        = aws_instance.presentation_tier_instance_b.id
  port             = 80
}

#application load balancer
resource "aws_lb" "app_alb" {
  name               = "3-tier-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
  tags = {
    Name = "3-tier-app-alb"
  }
}

#request the public certificate for the domain and www subdomain (last)
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "www.${var.domain_name}"
  ]
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-acm-cert"
  }
}
#DNS validation records route53
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}
#Wait for validation to complete (Blocks Terraform until AWS says "Verified")
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

#Listener: HTTP (80) -> Redirect to HTTPS
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}
#Listener: HTTPS (443) -> Forward to App
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.three_tier_tg.arn
  }
}

# DNS RECORDS (ALIAS TO LOAD BALANCER)

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name #root domain
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    #zone_id                = data.aws_route53_zone.main.zone_id
    zone_id                = var.alb_zone_id[var.aws_region] #"ZP97RAFLXTNZK" official, permanent Hosted Zone ID in the Mumbai (ap-south-1) region.
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_subdomain" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    #zone_id                = aws_lb.app_alb.zone_id
    zone_id                = var.alb_zone_id[var.aws_region] #"ZP97RAFLXTNZK" official, permanent Hosted Zone ID in the Mumbai (ap-south-1) region.
    evaluate_target_health = true
  }
}

#rds instance for db tier
resource "aws_security_group" "db_sg" {
  name        = "data-tier-sg"
  description = "Allow mysql traffic from app tier only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "mysql from app tier sg"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "data_tier_sg"
  }
}

#db subnet group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "three-tier-db-subnet-group"
  subnet_ids = [aws_subnet.private_3.id, aws_subnet.private_4.id]

  tags = {
    Name = "three-tier-db-subnet-group"
  }
}

#rds instance
resource "aws_db_instance" "rds_db" {
  identifier              = "three-tier-rds-instance"
  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20

  username              = var.db_username
  password              = var.db_password
  db_name               = "react_node_app"

  #network config
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids   = [aws_security_group.db_sg.id]
  multi_az                = false
  publicly_accessible     = false
  availability_zone       = "${var.aws_region}a"

  #backup and maintenance
  backup_retention_period = 0
  skip_final_snapshot     = true

  tags = {
    Name = "three-tier-rds-instance"
  }
}