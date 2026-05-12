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
  enable_autoscaling = false
  custom_tags = {
    Name       = var.cluster_name
    Owner      = "team-foo"
    DeployedBy = "terraform"
  }
  enable_new_user_data = true
}