resource "aws_security_group" "db_sg" {
  name        = "data-tier-sg"
  description = "Allow mysql traffic from app tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "mysql from app tier sg"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.app_tier_sg_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "data_tier_sg" }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "three-tier-db-subnet-group"
  subnet_ids = var.db_subnets
  tags       = { Name = "three-tier-db-subnet-group" }
}

resource "aws_db_instance" "rds_db" {
  identifier             = "three-tier-rds-instance"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.db_username
  password               = var.db_password
  db_name                = "react_node_app"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  multi_az               = false
  publicly_accessible    = false
  availability_zone      = "${var.aws_region}a"
  backup_retention_period = 0
  skip_final_snapshot     = true
  tags                    = { Name = "three-tier-rds-instance" }
}