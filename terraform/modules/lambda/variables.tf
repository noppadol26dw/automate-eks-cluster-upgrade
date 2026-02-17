variable "name_prefix" {
  type        = string
  default     = ""
  description = "Optional prefix for resource names"
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for notifications"
}

variable "enable_auto_upgrade" {
  type        = bool
  default     = false
  description = "Enable automatic upgrades for development clusters"
}

variable "target_environments" {
  type        = string
  default     = "dev,development"
  description = "Comma-separated list: only clusters whose name or Environment/Env tag contains one of these (case-insensitive) are processed. Empty = process all clusters."
}

variable "lambda_eks_checker_role_arn" {
  type        = string
  description = "IAM role ARN for EKS version checker Lambda"
}

variable "lambda_nodegroup_role_arn" {
  type        = string
  description = "IAM role ARN for node group version checker Lambda"
}
