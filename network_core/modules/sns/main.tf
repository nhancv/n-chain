# SNS topic
resource "aws_sns_topic" "change_instance" {
  name = "${var.env}-${var.project}-change-instance"
}
resource "aws_autoscaling_notification" "change_instance_noti" {
  group_names = var.group_names

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = aws_sns_topic.change_instance.arn
}
resource "aws_sns_topic_subscription" "email-target" {
  topic_arn = aws_sns_topic.change_instance.arn
  protocol  = "email"
  endpoint  = var.sns_endpoint
}
