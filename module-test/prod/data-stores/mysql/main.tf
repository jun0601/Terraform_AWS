terraform {
  backend "s3" {

    # This backend configuration is filled in automatically at test time by Terratest. If you wish to run this example
    # manually, uncomment and fill in the config below.

    bucket         = "zxxnwood-terraform-s3"
    key            = "mysql/prod/terraform.tfstate"
    region         = "ap-northeast-2"
    use_lockfile   = true
    encrypt        = true

  }
}

provider "aws" {
    region = "ap-northeast-2"
  
  # 2.x 버전의 AWS 공급자 허용
  version = ">= 5.50, < 6.0"
}

resource "aws_db_instance" "example" {
  identifier_prefix   = "prod-terraform-up-and-running"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"

  # 20Gib 이상 구성
  allocated_storage = 20
  storage_type = "gp3"

  username            = "admin"
  password            = jsondecode(
                          data.aws_secretsmanager_secret_version.db_password.secret_string
                        )["password"]

  db_name             = var.db_name               
  skip_final_snapshot = true
}

data "aws_secretsmanager_secret_version" "db_password" {
    secret_id = "soldesk_key"
}