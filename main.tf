locals {
  prefix = var.name_prefix
}

module "iam" {
  source = "./terraform/modules/iam"

  name_prefix = local.prefix
}

module "sns" {
  source = "./terraform/modules/sns"

  notification_email = var.notification_email
  name_prefix        = local.prefix
}

module "lambda" {
  source = "./terraform/modules/lambda"

  name_prefix                 = local.prefix
  sns_topic_arn               = module.sns.topic_arn
  enable_auto_upgrade         = var.enable_auto_upgrade
  target_environments         = var.target_environments
  lambda_eks_checker_role_arn = module.iam.lambda_eks_checker_role_arn
  lambda_nodegroup_role_arn   = module.iam.lambda_nodegroup_role_arn
}

module "scheduler" {
  source = "./terraform/modules/scheduler"

  name_prefix                         = local.prefix
  schedule_expression_version_checker = var.schedule_expression_version_checker
  schedule_expression_nodegroup       = var.schedule_expression_nodegroup
  eks_version_checker_lambda_arn      = module.lambda.eks_version_checker_arn
  nodegroup_version_checker_lambda_arn = module.lambda.nodegroup_version_checker_arn
  scheduler_role_arn                  = module.iam.scheduler_role_arn
  scheduler_role_id                   = module.iam.scheduler_role_id
  nodegroup_scheduler_role_arn        = module.iam.nodegroup_scheduler_role_arn
  nodegroup_scheduler_role_id         = module.iam.nodegroup_scheduler_role_id
}
