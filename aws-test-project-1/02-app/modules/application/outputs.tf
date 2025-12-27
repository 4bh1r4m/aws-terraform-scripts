output "app_tier_sg_id" { 
    value = aws_security_group.app_tier_sg.id 
    }
output "private_ip_a" { 
    value = aws_instance.application_tier_instance_a.private_ip 
    }
output "private_ip_b" { 
    value = aws_instance.application_tier_instance_b.private_ip 
    }