provider "aws" {
    region = "ap-northeast-2"
  
  # 2.x 버전의 AWS 공급자 허용
  version = "~> 2.0"
}

resource "aws_launch_template" "example" {
  name_prefix = "example-"
  image_id        = "ami-0d4c056a16f3ae150"
  instance_type   = "t3.micro"
  
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name = "JH_Keypair"
  user_data = <<-EOF
              #!/bin/bash
              dnf install -y httpd
              echo "Hello, World Server Port is ${var.server_port}" > /var/www/html/index.html
              systemctl enable --now httpd
              EOF

  # 오토스케일링 그룹과 함께 시작 구성을 사용할 때 필요합니다.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_template {
    id = aws_launch_template.example.id
    version = aws_launch_template.example.latest_version
  }
  
  availability_zones = ["ap-northeast-2a","ap-northeast-2c"]
  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "instance" {

  name = var.security_group_name

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}