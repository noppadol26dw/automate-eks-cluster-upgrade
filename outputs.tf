output "lambda_function_arn" {
  description = "ARN of the EKS Version Checker Lambda function"
  value       = module.lambda.eks_version_checker_arn
}

output "lambda_function_name" {
  description = "Name of the EKS Version Checker Lambda function"
  value       = module.lambda.eks_version_checker_name
}

output "nodegroup_lambda_function_arn" {
  description = "ARN of the EKS Node Group Version Checker Lambda function"
  value       = module.lambda.nodegroup_version_checker_arn
}

output "nodegroup_lambda_function_name" {
  description = "Name of the EKS Node Group Version Checker Lambda function"
  value       = module.lambda.nodegroup_version_checker_name
}

output "cloudwatch_alarm_eks_version_errors" {
  description = "ARN of the CloudWatch alarm for EKS version checker errors"
  value       = module.lambda.cloudwatch_alarm_eks_version_errors
}

output "cloudwatch_alarm_eks_version_throttles" {
  description = "ARN of the CloudWatch alarm for EKS version checker throttles"
  value       = module.lambda.cloudwatch_alarm_eks_version_throttles
}

output "cloudwatch_alarm_nodegroup_errors" {
  description = "ARN of the CloudWatch alarm for node group version checker errors"
  value       = module.lambda.cloudwatch_alarm_nodegroup_errors
}

output "cloudwatch_alarm_nodegroup_throttles" {
  description = "ARN of the CloudWatch alarm for node group version checker throttles"
  value       = module.lambda.cloudwatch_alarm_nodegroup_throttles
}

output "schedule_name" {
  description = "Name of the EventBridge Schedule for addon management"
  value       = module.scheduler.schedule_name
}

output "schedule_expression" {
  description = "Schedule expression for EKS version checker"
  value       = var.schedule_expression_version_checker
}

output "nodegroup_schedule_name" {
  description = "Name of the EventBridge Schedule for node group version checker"
  value       = module.scheduler.nodegroup_schedule_name
}

output "nodegroup_schedule_expression" {
  description = "Schedule expression for node group version checker"
  value       = var.schedule_expression_nodegroup
}

output "sns_topic_arn" {
  description = "ARN of the SNS notification topic"
  value       = module.sns.topic_arn
}

output "sns_topic_name" {
  description = "Name of the SNS notification topic"
  value       = module.sns.topic_name
}

output "iam_eks_checker_role_arn" {
  description = "ARN of the IAM role for EKS version checker Lambda"
  value       = module.iam.lambda_eks_checker_role_arn
}

output "iam_nodegroup_checker_role_arn" {
  description = "ARN of the IAM role for node group version checker Lambda"
  value       = module.iam.lambda_nodegroup_role_arn
}

output "iam_scheduler_role_arn" {
  description = "ARN of the IAM role for version checker scheduler"
  value       = module.iam.scheduler_role_arn
}

output "iam_nodegroup_scheduler_role_arn" {
  description = "ARN of the IAM role for node group scheduler"
  value       = module.iam.nodegroup_scheduler_role_arn
}
