variable "vpc_cidr" {
  type    = string
  default = "192.168.0.0/16"
}
variable "subnets" {
  type = map(any)
  default = {
    "public_sub_1" = {
      "newbit" = 8
      "netnum" = 10
      "az"     = "ap-southeast-1a"
    },
    "public_sub_2" = {
      "newbit" = 8
      "netnum" = 20
      "az"     = "ap-southeast-1b"
    },
    "private_sub_1" = {
      "newbit" = 8
      "netnum" = 30
      "az"     = "ap-southeast-1a"
    },
    "private_sub_2" = {
      "newbit" = 8
      "netnum" = 40
      "az"     = "ap-southeast-1b"
    }
  }
}

