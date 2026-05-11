provider "aws" {
    region = "ap-northeast-2"
  
  # 2.x 버전의 AWS 공급자 허용
  version = ">= 5.50, < 6.0"
}

module "webserver_cluster"{
  source               = "../../../modules/services/webserver-cluster"
  prefix               = "stage-"
  cluster_name         = var.cluster_name
  db_remote_state_key  = var.db_remote_state_key
  instance_type        = var.instance_type
  min_size             = var.min_size
  max_size             = var.max_size
}

resource "aws_security_group_rule" "allow_testing_inbound" {
  type              = "ingress"
  security_group_id = module.webserver_cluster.alb_security_group_id

  from_port   = 12345
  to_port     = 12345
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}