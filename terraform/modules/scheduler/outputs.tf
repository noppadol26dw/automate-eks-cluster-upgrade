output "schedule_name" {
  value = aws_scheduler_schedule.weekly.name
}

output "nodegroup_schedule_name" {
  value = aws_scheduler_schedule.nodegroup_weekly.name
}
