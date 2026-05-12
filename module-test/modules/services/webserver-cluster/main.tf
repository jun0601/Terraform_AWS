locals {
  http_port = 80
  any_port = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips = ["0.0.0.0/0"]
  user_data_file_name = var.enable_new_user_data ? "user-data-new.sh" : "user-data.sh"
}

resource "aws_launch_template" "example" {
  name_prefix   = var.prefix
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = base64encode(templatefile("${path.module}/${local.user_data_file_name}", {
    server_port = var.server_port
    db_user = "admin"
    db_password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
    db_address = data.terraform_remote_state.db.outputs.address
    db_port = data.terraform_remote_state.db.outputs.port
    alb_dns = aws_lb.example.dns_name
  }))
  key_name = "JH_Keypair"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_template {
    id = aws_launch_template.example.id
    version = aws_launch_template.example.latest_version
  }
  name = "${var.cluster_name}-${aws_launch_template.example.latest_version}"
  availability_zones = ["ap-northeast-2a","ap-northeast-2c"]
  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size
  lifecycle {
    create_before_destroy = true
  }

  dynamic "tag" {
  for_each = var.custom_tags

  content {
    key                 = tag.key
    value               = tag.value
    propagate_at_launch = true
  }
}
}
resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = var.enable_autoscaling ? 1 : 0
  scheduled_action_name = "scale-out-during-business-hours"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 4
  recurrence            = "0 9 * * *"

  autoscaling_group_name = aws_autoscaling_group.example.name
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  count = var.enable_autoscaling ? 1 : 0
  scheduled_action_name = "scale-in-at-night"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 2
  recurrence            = "0 18 * * *"

  autoscaling_group_name = aws_autoscaling_group.example.name
}


resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = local.any_protocol
    cidr_blocks = local.all_ips
  }
}

resource "aws_lb" "example" {

  name               = var.cluster_name

  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.http_port
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "asg" {

  name = var.cluster_name

  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern{
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

resource "aws_security_group" "alb" {

  name = "${var.cluster_name}--alb"

  # HTTP 인바운드 트래픽 허용
  ingress {
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips
  }

  # 모든 아웃바운트 트래픽 허용
  egress {
    from_port   = local.any_port
    to_port     = local.any_port
    protocol    = local.any_protocol
    cidr_blocks = local.all_ips
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  alarm_name = "{var.cluster_name}-high-cpu-utilization"
  namespace = "AWS/EC2"
  metric_name = "CPUUtilization"

  dimensions = {
    autoscaling_group_name = aws_autoscaling_group.example.name
  }
  
  comparison_operator   = "GreaterThanThreshold"
  evaluation_periods    = 1
  period                = 300
  statistic             = "Average"
  threshold             = 90
  unit                  = "Percent"
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_utilization" {
  count = format("%.1s", var.instance_type) == "t" ? 1 : 0
  
  alarm_name = "{var.cluster_name}-low-cpu-utilization"
  namespace = "AWS/EC2"
  metric_name = "CPUCreditBalance"

  dimensions = {
    autoscaling_group_name = aws_autoscaling_group.example.name
  }
  
  comparison_operator   = "LessThanThreshold"
  evaluation_periods    = 1
  period                = 300
  statistic             = "Minimum"
  threshold             = 10
  unit                  = "Count"
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "ap-northeast-2"
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
	  values = [data.aws_vpc.default.id]
  }
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "soldesk_key"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}