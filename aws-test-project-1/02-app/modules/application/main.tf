resource "aws_security_group" "app_tier_sg" {
  name        = "app-tier-sg"
  description = "Allow traffic from web tier sg, ssh and 3200"
  vpc_id      = var.vpc_id

  ingress {
    description     = "custom tcp 3200 from web tier sg"
    from_port       = 3200
    to_port         = 3200
    protocol        = "tcp"
    security_groups = [var.web_tier_sg_id]
  }
  ingress {
    description     = "SSH from anywhere (via jump host logic)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.web_tier_sg_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "app_tier_sg" }
}

resource "aws_instance" "application_tier_instance_a" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = var.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.app_tier_sg.id]
  key_name               = var.key_name

  tags = { Name = "application-tier-a" }

  user_data = templatefile("${path.module}/app-install.sh", {
    rds_endpoint       = var.rds_endpoint
    db_name            = "react_node_app"
    db_username        = "appuser"
    db_password        = "appuser123#"
    db_master_user     = var.db_master_user
    db_master_password = var.db_master_password
    run_db_init        = "true"
  })
}

resource "aws_instance" "application_tier_instance_b" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = var.private_subnets[1]
  vpc_security_group_ids = [aws_security_group.app_tier_sg.id]
  key_name               = var.key_name

  tags = { Name = "application-tier-b" }

  user_data = templatefile("${path.module}/app-install.sh", {
    rds_endpoint       = var.rds_endpoint
    db_name            = "react_node_app"
    db_username        = "appuser"
    db_password        = "appuser123#"
    db_master_user     = var.db_master_user
    db_master_password = var.db_master_password
    run_db_init        = "false"
  })
}