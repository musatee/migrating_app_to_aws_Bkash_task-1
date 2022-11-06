provider "aws" {
  profile = "bkash"
  region  = var.region
}
module "my_vpc" {
  source = "./modules/vpc"
}

##### create SG for ALB
resource "aws_security_group" "allow_tls" {
  name        = "webapp_ALB_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.my_vpc.vpc

  dynamic "ingress" {
    for_each = var.alb_ingress
    content {
      from_port   = ingress.value["port"]
      to_port     = ingress.value["port"]
      protocol    = ingress.value["protocol"]
      cidr_blocks = ingress.value["cidr_blocks"]
      description = ingress.value["description"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "webapp_ALB_SG"
    Created_By  = module.my_vpc.common_tags["Created_By"]
    Environment = module.my_vpc.common_tags["Environment"]
  }
  lifecycle {
    create_before_destroy = true
  }
}

#### create SG for RDS
resource "aws_security_group" "allow_tls_rds" {
  name        = "webapp_RDS_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.my_vpc.vpc
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [module.my_vpc.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "webapp_RDS_SG"
    Created_By  = module.my_vpc.common_tags["Created_By"]
    Environment = module.my_vpc.common_tags["Environment"]
  }
  lifecycle {
    create_before_destroy = true
  }
}

#### create RDS instance

resource "aws_db_instance" "webapp_rds" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  parameter_group_name   = "default.mysql5.7"
  identifier             = "webapp"
  skip_final_snapshot    = true
  db_subnet_group_name   = module.my_vpc.db_subnetgrp
  vpc_security_group_ids = [aws_security_group.allow_tls_rds.id]

  tags = {
    Name        = "webapp_RDS"
    Created_By  = module.my_vpc.common_tags["Created_By"]
    Environment = module.my_vpc.common_tags["Environment"]
  }

}

#### create ALB
resource "aws_lb" "test" {
  name               = "webapp-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_tls.id]
  subnets            = [module.my_vpc.public_sub_1.id, module.my_vpc.public_sub_2.id]

  #enable_deletion_protection = true 
  depends_on = [aws_db_instance.webapp_rds]

  tags = module.my_vpc.common_tags
}

## create TG_80
resource "aws_lb_target_group" "test_80" {
  name     = "webapp-ALB-TG-80"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.my_vpc.vpc
}
### create TG_443
resource "aws_lb_target_group" "test_443" {
  name     = "webapp-ALB-TG-443"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = module.my_vpc.vpc
}

#### create ALB listener 80
resource "aws_lb_listener" "front_end_80" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test_80.arn
  }
}
#### create ALB listener 443
resource "aws_lb_listener" "front_end_443" {
  load_balancer_arn = aws_lb.test.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test_443.arn
  }
}

### fetch latest available ami for ubuntu20.04 
data "aws_ami" "webapp_server_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

// generate a RSA private key
resource "tls_private_key" "rsa_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

// save the RSA private key locally
resource "local_file" "rsa_key_file" {
  content  = tls_private_key.rsa_key.private_key_pem
  filename = "webapp.pem"
  provisioner "local-exec" {
    command = "chmod 400 webapp.pem"
  }
}

// register the private key with aws by generating a key-pair 
resource "aws_key_pair" "webapp" {
  key_name   = "webapp"
  public_key = tls_private_key.rsa_key.public_key_openssh
}

resource "aws_launch_configuration" "as_conf" {
  name            = "webapp-lc"
  image_id        = data.aws_ami.webapp_server_ami.id
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.webapp.key_name
  security_groups = [aws_security_group.allow_tls.id]
  user_data       = <<-EOT
             #! /bin/bash
              apt update
              apt install apache2 php7.4 libapache2-mod-php7.4 php7.4-curl php-pear php7.4-gd php7.4-dev php7.4-zip php7.4-mbstring php7.4-mysql php7.4-xml -y
              sudo curl -sS https://getcomposer.org/installer | sudo php
              sudo mv composer.phar /usr/local/bin/composer
              sudo ln -s /usr/local/bin/composer /usr/bin/composer
              export COMPOSER_HOME="$HOME/.config/composer"

              cd /var/www &&  rm -rf html &&  git clone https://${var.github_access}:x-oauth-basic@github.com/musatee/ecaredemo.git html
              cd /var/www/html &&  cp .env.example .env &&  sed -i "s#^APP_DEBUG=.*#APP_DEBUG=false#; s#^DB_CONNECTION=.*#DB_CONNECTION=mysql#; s#^DB_HOST=.*#DB_HOST=${aws_db_instance.webapp_rds.address}#; s#^DB_DATABASE=.*#DB_DATABASE=${var.db_name}#; s#^DB_USERNAME=.*#DB_USERNAME=${var.db_user}#;s#^DB_PASSWORD=.*#DB_PASSWORD=${var.db_password}#" .env
              systemctl start apache2
              systemctl enable apache2
              a2enmod rewrite
              systemctl restart apache2 
              a2enmod ssl 
              systemctl restart apache2 
              cd /etc/apache2/sites-available/ && a2ensite default-ssl.conf 
              systemctl restart apache2

              sed  -i "s/^[ \t]*//; /^#/d; /ServerAdmin/ a ServerName ${var.domain}" /etc/apache2/sites-available/000-default.conf 
              sed  -i "s/^[ \t]*//; /^#/d; /ServerName/ a Redirect permanent / https://${var.domain}/" /etc/apache2/sites-available/000-default.conf 
              sed  -i "s/^[ \t]*//; /^#/d; /DocumentRoot/ s#DocumentRoot.*#DocumentRoot /var/www/html/public#" /etc/apache2/sites-available/000-default.conf
              sed  -i "s/^[ \t]*//; /^#/d; /ServerAdmin/ a ServerName ${var.domain}" /etc/apache2/sites-available/default-ssl.conf 
              sed  -i "s/^[ \t]*//; /^#/d; /DocumentRoot/ s#DocumentRoot.*#DocumentRoot /var/www/html/public#" /etc/apache2/sites-available/default-ssl.conf
             ### reload apache
              systemctl reload apache2 

             cd /var/www/html &&  composer update --no-interaction
             cd /var/www/html &&  composer install --no-interaction
             cd /var/www/html &&  php artisan key:generate --force
             cd /var/www/html &&  php artisan config:cache 
             cd /var/www/html &&  php artisan migrate:refresh --force

             
             cd /var/www/html && chown -R www-data:www-data . 
             ### reload apache
             systemctl reload apache2
 EOT
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_lb.test]
}
/// create auto-scaling group 
resource "aws_autoscaling_group" "bar" {
  name                      = "webapp-asg"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  #force_delete              = true
  #placement_group           = aws_placement_group.test.id
  launch_configuration = aws_launch_configuration.as_conf.name
  vpc_zone_identifier  = [module.my_vpc.private_sub_1.id, module.my_vpc.private_sub_2.id]
  target_group_arns    = [aws_lb_target_group.test_80.arn, aws_lb_target_group.test_443.arn]
  tag {
    key                 = "Name"
    value               = "webapp_ASG"
    propagate_at_launch = true
  }
}

//// create a sns topic with subscription to user-provided email address
resource "aws_sns_topic" "high_cpu_add_server" {
  name         = "high_cpu_add_server"
  display_name = "CPU_utilization_more_than_30%_adding_one_server"
}
resource "aws_sns_topic" "low_cpu_remove_server" {
  name         = "low_cpu_remove_server"
  display_name = "CPU_utilization_less_than_5%_removing_one_server"
}

resource "aws_sns_topic_subscription" "low_CPU_remove_Server" {
  topic_arn                       = aws_sns_topic.low_cpu_remove_server.arn
  protocol                        = "email"
  endpoint                        = var.sns_mail
  confirmation_timeout_in_minutes = 15
}
resource "aws_sns_topic_subscription" "high_CPU_add_Server" {
  topic_arn                       = aws_sns_topic.high_cpu_add_server.arn
  protocol                        = "email"
  endpoint                        = var.sns_mail
  confirmation_timeout_in_minutes = 15

}

/// adding simple scaling policy to ASG on scale-OUT
resource "aws_autoscaling_policy" "scale_out_policy" {
  name                   = "example-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.bar.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}
/// adding simple scaling policy to ASG on scale-IN
resource "aws_autoscaling_policy" "scale_in_policy" {
  name                   = "example-cpu-policy-scaledown"
  autoscaling_group_name = aws_autoscaling_group.bar.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

// create clouwdwatch alarm , it triggers scale-OUT scaling policy & send sns mail
resource "aws_cloudwatch_metric_alarm" "alarm_high_CPU" {
  alarm_name          = "alarm-high-cpu"
  alarm_description   = "alarm-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.bar.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_out_policy.arn, aws_sns_topic.high_cpu_add_server.arn]
}

//create clouwdwatch alarm , it triggers scale-IN scaling policy & send sns mail
resource "aws_cloudwatch_metric_alarm" "alarm_low_CPU" {
  alarm_name          = "alarm-low-cpu"
  alarm_description   = "alarm-low-cpu"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "5"
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.bar.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_in_policy.arn, aws_sns_topic.low_cpu_remove_server.arn]
}
