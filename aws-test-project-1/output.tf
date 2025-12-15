/*
#output the name server
output "name_servers" {
  description = "name server data for hostinger"
  value = aws_route53_zone.main.name_servers
}
*/

#print output public ip of presentation tier instances
output "presentation_tier_a_ip" {
  value = aws_instance.presentation_tier_instance_a.public_ip
}

output "presentation_tier_b_ip" {
  value = aws_instance.presentation_tier_instance_b.public_ip
}

#output the private ip of the private app tier instances
output "application_tier_a_private_ip" {
  value = aws_instance.application_tier_instance_a.private_ip
}

output "application_tier_b_private_ip" {
  value = aws_instance.application_tier_instance_b.private_ip
}

output "alb_dns_name" {
  description = "The DNS name of the Load Balancer"
  value       = aws_lb.app_alb.dns_name
}