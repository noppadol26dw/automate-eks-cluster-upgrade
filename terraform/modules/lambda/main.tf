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
  timeout          = 120
  filename         = data.archive_file.eks_version_checker.output_path
  source_code_hash = data.archive_file.eks_version_checker.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN        = var.sns_topic_arn
      ENABLE_AUTO_UPGRADE  = var.enable_auto_upgrade ? "true" : "false"
      TARGET_ENVIRONMENTS  = var.target_environments
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
      SNS_TOPIC_ARN        = var.sns_topic_arn
      ENABLE_AUTO_UPGRADE  = var.enable_auto_upgrade ? "true" : "false"
      TARGET_ENVIRONMENTS  = var.target_environments
    }
  }
}
