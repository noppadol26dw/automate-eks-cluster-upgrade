locals {
  prefix = var.name_prefix
}

resource "aws_iam_role" "lambda_eks_checker" {
  name = "${local.prefix}eks-version-checker-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_eks_checker_basic" {
  role       = aws_iam_role.lambda_eks_checker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_eks_checker_eks" {
  name = "EKSReadAccess"
  role = aws_iam_role.lambda_eks_checker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:DescribeClusterVersions",
        "eks:UpdateClusterVersion",
        "eks:ListInsights",
        "eks:ListAddons",
        "eks:DescribeAddon",
        "eks:DescribeAddonVersions",
        "eks:UpdateAddon",
        "eks:DescribePodIdentityAssociation",
        "eks:UpdatePodIdentityAssociation",
        "sns:Publish",
        "iam:PassRole",
        "iam:GetRole"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "scheduler" {
  name = "${local.prefix}eks-version-checker-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "lambda_nodegroup" {
  name = "${local.prefix}eks-nodegroup-version-checker-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_nodegroup_basic" {
  role       = aws_iam_role.lambda_nodegroup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_nodegroup_eks" {
  name = "EKSNodeGroupAccess"
  role = aws_iam_role.lambda_nodegroup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:ListNodegroups",
        "eks:DescribeNodegroup",
        "eks:UpdateNodegroupVersion",
        "sns:Publish"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "nodegroup_scheduler" {
  name = "${local.prefix}eks-nodegroup-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
