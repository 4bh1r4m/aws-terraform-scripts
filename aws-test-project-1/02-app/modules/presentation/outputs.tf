output "web_tier_sg_id" { 
    value = aws_security_group.web_tier_sg.id 
    }
output "presentation_a_public_ip" { 
    value = aws_instance.presentation_tier_instance_a.public_ip 
    }
output "presentation_b_public_ip" { 
    value = aws_instance.presentation_tier_instance_b.public_ip 
    }
output "alb_dns_name" { 
    value = aws_lb.app_alb.dns_name 
    }