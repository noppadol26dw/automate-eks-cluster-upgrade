variable "notification_email" {
  type        = string
  description = "Email address to receive EKS upgrade notifications"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "The notification_email must be a valid email address."
  }
}

variable "name_prefix" {
  type        = string
  default     = ""
  description = "Optional prefix for resource names"
}
