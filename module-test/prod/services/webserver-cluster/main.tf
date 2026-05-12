provider "aws" {
    region = "ap-northeast-2"
  
  # 2.x 버전의 AWS 공급자 허용
  version = ">= 5.50, < 6.0"
}

module "webserver_cluster"{
  source               = "../../../modules/services/webserver-cluster"
  prefix               = "prod-"

  cluster_name         = var.cluster_name
  db_remote_state_bucket = var.db_remote_state_bucket
  db_remote_state_key  = var.db_remote_state_key
  enable_autoscaling   = true
  instance_type        = "m4.large"
  min_size             = 2
  max_size             = 10
  enable_new_user_data = false
}


