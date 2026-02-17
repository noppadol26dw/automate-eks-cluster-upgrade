output "eks_version_checker_arn" {
  value = aws_lambda_function.eks_version_checker.arn
}

output "nodegroup_version_checker_arn" {
  value = aws_lambda_function.nodegroup_version_checker.arn
}
