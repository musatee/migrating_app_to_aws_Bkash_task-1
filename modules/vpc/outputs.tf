output "vpc" {
  value = aws_vpc.webapp_vpc.id
}
output "vpc_cidr" {
  value = aws_vpc.webapp_vpc.cidr_block
}
output "public_sub_1" {
  value = aws_subnet.webapp_sub["public_sub_1"]
}
output "public_sub_2" {
  value = aws_subnet.webapp_sub["public_sub_2"]
}
output "private_sub_1" {
  value = aws_subnet.webapp_sub["private_sub_1"]
}
output "private_sub_2" {
  value = aws_subnet.webapp_sub["private_sub_2"]
}
output "common_tags" {
  value = {
    Created_By  = local.common_tags["Created_By"]
    Environment = local.common_tags["Environment"]
  }
}

output "db_subnetgrp" {
  value = aws_db_subnet_group.webapp.name
}
