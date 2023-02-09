variable "domain_name" {
  type        = string
  description = "The domain name to request a certificate for"
}

variable "alb_logs_expiration_days" {
  type        = number
  description = "The number of days after which logs expire"
  default     = 30
}

variable "ec2_instance_type" {
  type        = string
  description = "the ec2 instance type"
  default     = null
}

variable "ec2_disk_allocation_gb" {
  type        = number
  default     = null
  description = "how large the persistent root ebs volume will be"
}

variable "ebs_volume_disk_allocation_gb" {
  type        = number
  default     = null
  description = "how large the persistent data ebs volume will be"
}
