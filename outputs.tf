
output "ec2_instance_id" {
  value = aws_instance.default[0].id
}
