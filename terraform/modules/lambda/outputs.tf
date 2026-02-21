output "eks_version_checker_arn" {
  value = aws_lambda_function.eks_version_checker.arn
}

output "eks_version_checker_name" {
  value = aws_lambda_function.eks_version_checker.function_name
}

output "nodegroup_version_checker_arn" {
  value = aws_lambda_function.nodegroup_version_checker.arn
}

output "nodegroup_version_checker_name" {
  value = aws_lambda_function.nodegroup_version_checker.function_name
}

output "cloudwatch_alarm_eks_version_errors" {
  value = aws_cloudwatch_metric_alarm.eks_version_checker_errors.arn
}

output "cloudwatch_alarm_eks_version_throttles" {
  value = aws_cloudwatch_metric_alarm.eks_version_checker_throttles.arn
}

output "cloudwatch_alarm_nodegroup_errors" {
  value = aws_cloudwatch_metric_alarm.nodegroup_version_checker_errors.arn
}

output "cloudwatch_alarm_nodegroup_throttles" {
  value = aws_cloudwatch_metric_alarm.nodegroup_version_checker_throttles.arn
}
