variable "notification_email" {
  type        = string
  description = "Email address to receive EKS upgrade notifications"
}

variable "name_prefix" {
  type        = string
  default     = ""
  description = "Optional prefix for resource names"
}
