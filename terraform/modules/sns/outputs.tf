output "topic_arn" {
  value = aws_sns_topic.eks_upgrade.arn
}

output "topic_name" {
  value = aws_sns_topic.eks_upgrade.name
}
