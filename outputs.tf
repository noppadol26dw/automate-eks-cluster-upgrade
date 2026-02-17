output "lambda_function_arn" {
  description = "ARN of the EKS Version Checker Lambda function"
  value       = module.lambda.eks_version_checker_arn
}

output "nodegroup_lambda_function_arn" {
  description = "ARN of the EKS Node Group Version Checker Lambda function"
  value       = module.lambda.nodegroup_version_checker_arn
}

output "schedule_name" {
  description = "Name of the EventBridge Schedule for addon management"
  value       = module.scheduler.schedule_name
}

output "nodegroup_schedule_name" {
  description = "Name of the EventBridge Schedule for node group version checker"
  value       = module.scheduler.nodegroup_schedule_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS notification topic"
  value       = module.sns.topic_arn
}
