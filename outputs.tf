output "ALB_endpoint" {
  value = "Point ${aws_lb.test.dns_name} to the domain: ${var.domain} at domain control Panel"
}
