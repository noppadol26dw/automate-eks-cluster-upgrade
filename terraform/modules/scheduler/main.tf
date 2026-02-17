locals {
  prefix = var.name_prefix
}

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name = "InvokeLambda"
  role = var.scheduler_role_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = var.eks_version_checker_lambda_arn
    }]
  })
}

resource "aws_iam_role_policy" "nodegroup_scheduler_invoke" {
  name = "InvokeNodeGroupLambda"
  role = var.nodegroup_scheduler_role_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = var.nodegroup_version_checker_lambda_arn
    }]
  })
}

resource "aws_scheduler_schedule" "weekly" {
  name                = "${local.prefix}eks-version-checker-weekly"
  schedule_expression = var.schedule_expression_version_checker
  flexible_time_window {
    mode = "OFF"
  }
  target {
    arn      = var.eks_version_checker_lambda_arn
    role_arn = var.scheduler_role_arn
  }
}

resource "aws_scheduler_schedule" "nodegroup_weekly" {
  name                = "${local.prefix}eks-nodegroup-version-checker-weekly"
  description         = "Triggers node group version checker 1 hour after addon management"
  schedule_expression = var.schedule_expression_nodegroup
  flexible_time_window {
    mode = "OFF"
  }
  target {
    arn      = var.nodegroup_version_checker_lambda_arn
    role_arn = var.nodegroup_scheduler_role_arn
  }
}
