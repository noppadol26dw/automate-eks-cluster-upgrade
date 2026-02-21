variable "notification_email" {
  type        = string
  description = "Email address to receive EKS upgrade notifications"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "The notification_email must be a valid email address."
  }
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

  validation {
    condition     = can(regex("^cron\\(.+\\)$", var.schedule_expression_version_checker)) || can(regex("^rate\\(.+\\)$", var.schedule_expression_version_checker))
    error_message = "The schedule_expression_version_checker must be a valid EventBridge Scheduler expression (e.g., 'cron(0 17 ? * FRI *)' or 'rate(1 day)')."
  }
}

variable "schedule_expression_nodegroup" {
  type        = string
  default     = "cron(0 18 ? * FRI *)"
  description = "EventBridge cron/rate for node group version checker. Default: Fridays 18:00 UTC."

  validation {
    condition     = can(regex("^cron\\(.+\\)$", var.schedule_expression_nodegroup)) || can(regex("^rate\\(.+\\)$", var.schedule_expression_nodegroup))
    error_message = "The schedule_expression_nodegroup must be a valid EventBridge Scheduler expression (e.g., 'cron(0 18 ? * FRI *)' or 'rate(1 day)')."
  }
}

variable "target_environments" {
  type        = string
  default     = "dev,development"
  description = "Comma-separated: only clusters whose name or Environment/Env tag contains one of these are processed. Empty = all clusters."
}

variable "max_parallel_addons" {
  type        = number
  default     = 3
  description = "Maximum number of addons to update in parallel. Default: 3. Recommended: 3-5 for production, 5-10 for development."

  validation {
    condition     = var.max_parallel_addons >= 1 && var.max_parallel_addons <= 10
    error_message = "max_parallel_addons must be between 1 and 10."
  }
}

variable "max_addons_per_run" {
  type        = number
  default     = 30
  description = "Maximum number of addons to process per Lambda execution. Remaining addons will be processed in the next scheduled run."

  validation {
    condition     = var.max_addons_per_run >= 1 && var.max_addons_per_run <= 100
    error_message = "max_addons_per_run must be between 1 and 100."
  }
}

variable "dry_run" {
  type        = bool
  default     = false
  description = "Enable dry-run mode to simulate updates without making changes. Useful for testing without a cluster."
}
