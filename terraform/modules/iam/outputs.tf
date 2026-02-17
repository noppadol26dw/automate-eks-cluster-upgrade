output "lambda_eks_checker_role_arn" {
  value = aws_iam_role.lambda_eks_checker.arn
}

output "lambda_nodegroup_role_arn" {
  value = aws_iam_role.lambda_nodegroup.arn
}

output "scheduler_role_arn" {
  value = aws_iam_role.scheduler.arn
}

output "scheduler_role_id" {
  value = aws_iam_role.scheduler.id
}

output "nodegroup_scheduler_role_arn" {
  value = aws_iam_role.nodegroup_scheduler.arn
}

output "nodegroup_scheduler_role_id" {
  value = aws_iam_role.nodegroup_scheduler.id
}
