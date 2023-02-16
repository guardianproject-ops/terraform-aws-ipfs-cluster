
output "ec2_instance_id" {
  description = "The instance ID of the EC2 instance."
  value       = aws_instance.default[0].id
}

output "domain_name" {
  description = "The base domain name for the deployment. Subdomains of this domain will be used for the gateway, swarm and pinning services."
  value       = var.domain_name
}

output "gateway_domain_name" {
  description = "The domain name of the gateway endpoint."
  value       = "gateway.${var.domain_name}"
}

output "pinning_domain_name" {
  description = "The domain name of the pinning endpoint."
  value       = "pinning.${var.domain_name}"
}

output "swarm_domain_name" {
  description = "The domain name of the swarm endpoint."
  value       = "swarm.${var.domain_name}"
}