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

/*
#hosted zone creation
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Environment = "dev"
    project = "3-tier-app"
  }
}

#request the certificate for the domain and www subdomain (last)
*/

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

#key pair upload to aws
resource "aws_key_pair" "deployer_key" {
  key_name   = "web-tier-key"
  public_key = file("${path.module}/ssh-keys/ed25519.pub")
}
#security group for web tier
resource "aws_security_group" "web_tier_sg" {
  name        = "web-tier-sg"
  description = "Allow HTTP and SSH inbound traffic"
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

  tags = {
    Name = "presentation-tier-a"
  }
  user_data = <<-EOF
              #!/bin/bash
              yum install nginx -y
              systemctl start nginx
              systemctl enable nginx
              echo "Welcome to Presentation tier instance in AZ-A" > /usr/share/nginx/html/index.html
              systemctl restart nginx
              # TERRAFORM INJECTED KEY (No manual copy-pasting needed!)
              cat <<'KEY_FILE'> /home/ec2-user/id_ed25519
              ${file("${path.module}/ssh-keys/ed25519")}
              KEY_FILE
              chown ec2-user:ec2-user /home/ec2-user/id_ed25519
              chmod 600 /home/ec2-user/id_ed25519
              EOF
}

resource "aws_instance" "presentation_tier_instance_b" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_2.id
  vpc_security_group_ids      = [aws_security_group.web_tier_sg.id]
  key_name                    = aws_key_pair.deployer_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "presentation-tier-b"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum install nginx -y
              systemctl start nginx
              systemctl enable nginx
              echo "Welcome to Presentation tier instance in AZ-B" > /usr/share/nginx/html/index.html
              systemctl restart nginx

              # TERRAFORM INJECTED KEY (No manual copy-pasting needed!)
              cat <<'KEY_FILE'> /home/ec2-user/id_ed25519
              ${file("${path.module}/ssh-keys/ed25519")}
              KEY_FILE
              chown ec2-user:ec2-user /home/ec2-user/id_ed25519
              chmod 600 /home/ec2-user/id_ed25519
              EOF
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
  name     = "3-tier-target-gp"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id  
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
#listener for ALB
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.three_tier_tg.arn
  }
}
