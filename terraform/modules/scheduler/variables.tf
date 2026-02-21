variable "name_prefix" {
  type        = string
  default     = ""
  description = "Optional prefix for resource names"
}

variable "schedule_expression_version_checker" {
  type        = string
  default     = "cron(0 17 ? * FRI *)"
  description = "EventBridge Schedule expression for EKS version checker (cron or rate). Default: Fridays 17:00 UTC."

  validation {
    condition     = can(regex("^cron\\(.+\\)$", var.schedule_expression_version_checker)) || can(regex("^rate\\(.+\\)$", var.schedule_expression_version_checker))
    error_message = "The schedule_expression_version_checker must be a valid EventBridge Scheduler expression (e.g., 'cron(0 17 ? * FRI *)' or 'rate(1 day)')."
  }
}

variable "schedule_expression_nodegroup" {
  type        = string
  default     = "cron(0 18 ? * FRI *)"
  description = "EventBridge Schedule expression for node group version checker. Default: Fridays 18:00 UTC."

  validation {
    condition     = can(regex("^cron\\(.+\\)$", var.schedule_expression_nodegroup)) || can(regex("^rate\\(.+\\)$", var.schedule_expression_nodegroup))
    error_message = "The schedule_expression_nodegroup must be a valid EventBridge Scheduler expression (e.g., 'cron(0 18 ? * FRI *)' or 'rate(1 day)')."
  }
}

variable "eks_version_checker_lambda_arn" {
  type        = string
  description = "ARN of the EKS version checker Lambda function"
}

variable "nodegroup_version_checker_lambda_arn" {
  type        = string
  description = "ARN of the node group version checker Lambda function"
}

variable "scheduler_role_arn" {
  type        = string
  description = "ARN of the IAM role for the version checker schedule"
}

variable "scheduler_role_id" {
  type        = string
  description = "ID of the IAM role for the version checker schedule (for attaching policy)"
}

variable "nodegroup_scheduler_role_arn" {
  type        = string
  description = "ARN of the IAM role for the node group schedule"
}

variable "nodegroup_scheduler_role_id" {
  type        = string
  description = "ID of the IAM role for the node group schedule (for attaching policy)"
}
