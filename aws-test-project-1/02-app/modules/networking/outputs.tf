output "vpc_id" { 
    value = aws_vpc.main.id 
    }
output "public_subnets" { 
    value = [aws_subnet.public_1.id, aws_subnet.public_2.id] 
    }
output "app_subnets" { 
    value = [aws_subnet.private_1.id, aws_subnet.private_2.id] 
    }
output "db_subnets" { 
    value = [aws_subnet.private_3.id, aws_subnet.private_4.id] 
    }