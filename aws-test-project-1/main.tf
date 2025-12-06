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

#output the name server
output "name_servers" {
  description = "name server data for hostinger"
  value = aws_route53_zone.main.name_servers
}

#request the certificate for the domain and www subdomain (last)
*/

#create Vpc
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-vpc"
    Environment = "dev"
    project = "${var.project_name}"
  }
}
#internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
    }
}
resource "aws_subnet" "public_1"{
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.0.0/20"
  availability_zone = "${var.aws_region}a"
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
  tags= {
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
  domain= "vpc"
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
  vpc_id= aws_vpc.main.id
  route{
    cidr_block="0.0.0.0/0"
    gateway_id= aws_internet_gateway.gw.id
  }
  tags={
    Name= "${var.project_name}-public-rt"
  }
}
#private routetable
resource "aws_route_table" "private" {
  vpc_id= aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags= { 
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