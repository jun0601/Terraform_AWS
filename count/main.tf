provider "aws" {
    region = "ap-northeast-2"
  
  # 2.x 버전의 AWS 공급자 허용
  version = ">= 5.50, < 6.0"
}

resource "aws_iam_user" "example" {
    for_each = toset(var.user_names)
    name = each.value
}