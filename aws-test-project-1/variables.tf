variable "aws_region" {
  description = "aws default region"
  type        = string
  default     = "ap-south-1"
}
variable "domain_name" {
  description = "domain for the project"
  type        = string
  default     = "pointbreak.space"
}

variable "vpc_cidr" {
  description = "CIDR block for the vpcs"
  type        = string
  default     = "10.0.0.0/16"
}
variable "project_name" {
  description = "project name prefix for tags"
  type        = string
  default     = "3-tier-arch"
}
variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0d176f79571d18a8f" #amazon linux
}
