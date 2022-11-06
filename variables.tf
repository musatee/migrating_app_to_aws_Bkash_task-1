variable "alb_ingress" {
  type = map(object(
    {
      port        = number
      protocol    = string
      cidr_blocks = list(string)
      description = string
    }
  ))
  default = {
    "80" = {
      "port"        = 80
      "protocol"    = "tcp"
      "cidr_blocks" = ["0.0.0.0/0"]
      "description" = "allow http"
    },
    "443" = {
      "port"        = 443
      "protocol"    = "tcp"
      "cidr_blocks" = ["0.0.0.0/0"]
      "description" = "allow https"
    }
  }
}
variable "db_name" {
  description = "database name"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "database password"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Password lenth must be at least 8 character long."
  }
}

variable "domain" {
  type    = string
  default = "ekyc-test.tk"
}
variable "acm_arn" {
  type    = string
  default = "arn:aws:acm:ap-southeast-1:115391213665:certificate/819077df-fa8e-4416-907c-76758f19c8fd"
}

variable "db_user" {
  type        = string
  description = "db username"
}
variable "github_access" {
  type    = string
  default = "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"

}

variable "sns_mail" {
  type        = string
  description = "Enter your email address to get notified on EC2 scale-in/scale-out"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}
