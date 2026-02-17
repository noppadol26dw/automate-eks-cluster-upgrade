variable "notification_email" {
  type        = string
  description = "Email address to receive EKS upgrade notifications"
}

variable "enable_auto_upgrade" {
  type        = bool
  default     = false
  description = "Enable automatic upgrades for development clusters"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for resources"
}

variable "name_prefix" {
  type        = string
  default     = ""
  description = "Optional prefix for resource names (e.g. dev-, prod-)"
}

variable "schedule_expression_version_checker" {
  type        = string
  default     = "cron(0 17 ? * FRI *)"
  description = "EventBridge cron/rate for EKS version checker. Default: Fridays 17:00 UTC."
}

variable "schedule_expression_nodegroup" {
  type        = string
  default     = "cron(0 18 ? * FRI *)"
  description = "EventBridge cron/rate for node group version checker. Default: Fridays 18:00 UTC."
}

variable "target_environments" {
  type        = string
  default     = "dev,development"
  description = "Comma-separated: only clusters whose name or Environment/Env tag contains one of these are processed. Empty = all clusters."
}
