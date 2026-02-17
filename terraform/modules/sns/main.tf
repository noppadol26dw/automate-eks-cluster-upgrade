locals {
  prefix = var.name_prefix
}

resource "aws_sns_topic" "eks_upgrade" {
  name = "${local.prefix}eks-upgrade-notifications"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.eks_upgrade.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
