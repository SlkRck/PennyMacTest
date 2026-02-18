output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "vpce_sg_id" {
  value = aws_security_group.vpce.id
}
