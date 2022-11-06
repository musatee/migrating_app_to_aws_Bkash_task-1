output "ALB_endpoint" {
  value = "Point ${aws_lb.test.dns_name} to the domain: ${var.domain} at domain control Panel"
}

output "confirm_subscription_to_sns_topic" {
  value = "Please confirm subscription mail sent to ${var.sns_mail} for sns topics"
}