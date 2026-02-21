locals {
  prefix = var.name_prefix
}

data "archive_file" "eks_version_checker" {
  type        = "zip"
  source_file = "${path.module}/eks_version_checker/index.py"
  output_path = "${path.module}/build/eks_version_checker.zip"
}

resource "aws_lambda_function" "eks_version_checker" {
  function_name    = "${local.prefix}eks-version-checker"
  role             = var.lambda_eks_checker_role_arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 300
  filename         = data.archive_file.eks_version_checker.output_path
  source_code_hash = data.archive_file.eks_version_checker.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN       = var.sns_topic_arn
      ENABLE_AUTO_UPGRADE = var.enable_auto_upgrade ? "true" : "false"
      TARGET_ENVIRONMENTS = var.target_environments
      MAX_PARALLEL_ADDONS = var.max_parallel_addons
      MAX_ADDONS_PER_RUN  = var.max_addons_per_run
      DRY_RUN             = var.dry_run ? "true" : "false"
    }
  }
}

data "archive_file" "nodegroup_version_checker" {
  type        = "zip"
  source_file = "${path.module}/nodegroup_version_checker/index.py"
  output_path = "${path.module}/build/nodegroup_version_checker.zip"
}

resource "aws_lambda_function" "nodegroup_version_checker" {
  function_name    = "${local.prefix}eks-nodegroup-version-checker"
  role             = var.lambda_nodegroup_role_arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 300
  filename         = data.archive_file.nodegroup_version_checker.output_path
  source_code_hash = data.archive_file.nodegroup_version_checker.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN       = var.sns_topic_arn
      ENABLE_AUTO_UPGRADE = var.enable_auto_upgrade ? "true" : "false"
      TARGET_ENVIRONMENTS = var.target_environments
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "eks_version_checker_errors" {
  alarm_name          = "${local.prefix}eks-version-checker-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alarm for EKS version checker Lambda errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.eks_version_checker.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "eks_version_checker_throttles" {
  alarm_name          = "${local.prefix}eks-version-checker-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alarm for EKS version checker Lambda throttles"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.eks_version_checker.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "nodegroup_version_checker_errors" {
  alarm_name          = "${local.prefix}eks-nodegroup-version-checker-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alarm for node group version checker Lambda errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.nodegroup_version_checker.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "nodegroup_version_checker_throttles" {
  alarm_name          = "${local.prefix}eks-nodegroup-version-checker-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alarm for node group version checker Lambda throttles"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.nodegroup_version_checker.function_name
  }
}
