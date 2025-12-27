#Data Sources
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

#Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "application-load-balancer-sg"
  description = "Allow HTTP inbound traffic to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS from anywhere"
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
  tags = { Name = "alb_sg" }
}

resource "aws_security_group" "web_tier_sg" {
  name        = "web-tier-sg"
  description = "Allow HTTP from alb sg and SSH inbound"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from alb sg"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
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
  tags = { Name = "web_tier_sg" }
}

#Instances
resource "aws_instance" "presentation_tier_instance_a" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  subnet_id                   = var.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.web_tier_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  tags                        = { Name = "presentation-tier-a" }

  user_data = templatefile("${path.module}/web-install.sh", {
    app_tier_ip     = var.app_tier_ip_a
    ssh_private_key = var.ssh_private_key
  })
  user_data_replace_on_change = true
}

resource "aws_instance" "presentation_tier_instance_b" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  subnet_id                   = var.public_subnets[1]
  vpc_security_group_ids      = [aws_security_group.web_tier_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  tags                        = { Name = "presentation-tier-b" }

  user_data = templatefile("${path.module}/web-install.sh", {
    app_tier_ip     = var.app_tier_ip_b
    ssh_private_key = var.ssh_private_key
  })
  user_data_replace_on_change = true
}

#Load Balancer & Target Groups
resource "aws_lb_target_group" "three_tier_tg" {
  name        = "3-tier-target-gp"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
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
  tags = { Name = "app-tg" }
}

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

resource "aws_lb" "app_alb" {
  name               = "3-tier-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets
  tags               = { Name = "3-tier-app-alb" }
}

#ACM & Route53
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  subject_alternative_names = ["www.${var.domain_name}"]
  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-acm-cert" }
}

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

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

#Listeners
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

#Route53 Alias Records
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_subdomain" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}