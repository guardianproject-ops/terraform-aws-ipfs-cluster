variable "dns_zone_name" {
  type        = string
  description = "The name of the DNS zone hosted in Route 53 that should be used to create the DNS records."
}

variable "domain_name" {
  type        = string
  description = <<EOT
    The base domain name for the deployment. Subdomains of this domain will be used for the gateway, swarm and pinning
    services.
  EOT
}

variable "alb_logs_expiration_days" {
  type        = number
  description = "The number of days after which the application load balancer's logs expire."
  default     = 30
}

variable "ec2_instance_type" {
  type        = string
  description = "The EC2 instance class to use."
  default     = null
}

variable "ec2_disk_allocation_gb" {
  type        = number
  default     = null
  description = "How much disk space to allocate for the EC2 instance's root EBS volume."
}

variable "ebs_volume_disk_allocation_gb" {
  type        = number
  default     = null
  description = "How much disk space to allocate for the EC2 instance's data EBS volume."
}
