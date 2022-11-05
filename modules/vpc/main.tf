locals {
  Name       = "webapp"
  Created_By = "terraform"
}
locals {
  common_tags = {
    Name        = local.Name
    Created_By  = local.Created_By
    Environment = terraform.workspace
  }
}
// create vpc
resource "aws_vpc" "webapp_vpc" {
  cidr_block = var.vpc_cidr
  tags       = local.common_tags
}

//create two privates & two public subnet
resource "aws_subnet" "webapp_sub" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.webapp_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.webapp_vpc.cidr_block, each.value["newbit"], each.value["netnum"])
  availability_zone = each.value["az"]

  tags = {
    Name        = each.key
    Created_By  = local.common_tags["Created_By"]
    Environment = local.common_tags["Environment"]
  }
}

// create IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.webapp_vpc.id

  tags = {
    Name        = "webapp-IGW"
    Created_By  = local.common_tags["Created_By"]
    Environment = local.common_tags["Environment"]
  }
}

// create EIP for use in NAT 
resource "aws_eip" "NAT_eip" {
  vpc = true
  tags = {
    Name        = "webapp_NAT"
    Created_By  = local.common_tags["Created_By"]
    Environment = local.common_tags["Environment"]
  }
}
// create NAT 
resource "aws_nat_gateway" "webapp_NAT" {
  allocation_id = aws_eip.NAT_eip.id
  subnet_id     = aws_subnet.webapp_sub["public_sub_1"].id

  tags = {
    Name        = "webapp_NAT"
    Created_By  = local.common_tags["Created_By"]
    Environment = local.common_tags["Environment"]
  }

  depends_on = [aws_internet_gateway.igw]
}

// create public RT 
resource "aws_route_table" "webapp_publicRT" {
  vpc_id = aws_vpc.webapp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "webapp_publicRT"
    Created_By  = local.common_tags["Created_By"]
    Environment = local.common_tags["Environment"]
  }
}

// associate public_sub_1 to RT 
resource "aws_route_table_association" "RT_assoc_1" {
  subnet_id      = aws_subnet.webapp_sub["public_sub_1"].id
  route_table_id = aws_route_table.webapp_publicRT.id
}

// associate public_sub_2 to RT 
resource "aws_route_table_association" "RT_assoc_2" {
  subnet_id      = aws_subnet.webapp_sub["public_sub_2"].id
  route_table_id = aws_route_table.webapp_publicRT.id
}

// create private RT for private subnets 
resource "aws_route_table" "webapp_privateRT" {
  vpc_id = aws_vpc.webapp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.webapp_NAT.id
  }

  tags = {
    Name        = "webapp_privateRT"
    Created_By  = local.common_tags["Created_By"]
    Environment = local.common_tags["Environment"]
  }
}

// associate private subnets to RT 
resource "aws_route_table_association" "privateRT_assoc" {
  subnet_id      = aws_subnet.webapp_sub["private_sub_1"].id
  route_table_id = aws_route_table.webapp_privateRT.id
}

// associate private subnets to RT 
resource "aws_route_table_association" "privateRT_assoc2" {
  subnet_id      = aws_subnet.webapp_sub["private_sub_2"].id
  route_table_id = aws_route_table.webapp_privateRT.id
}

// create db subnet-group
resource "aws_db_subnet_group" "webapp" {
  name       = "webapp_subnetgrp"
  subnet_ids = [aws_subnet.webapp_sub["private_sub_1"].id, aws_subnet.webapp_sub["private_sub_2"].id]

  tags = {
    Name        = "My DB subnet group"
    Created_By  = local.common_tags["Created_By"]
    Environment = local.common_tags["Environment"]
  }
}