###
################################################################################
# Version
################################################################################

terraform {
  required_version = "~> 1.9.0"

  backend "remote" {
    workspaces {
      prefix = "server-"
    }
  }
}

################################################################################
# Variable
################################################################################

variable "terraform_env" {
  description = "terraform_env"
  type        = string
}

variable "prefix" {
  description = "prefix"
  type        = string
}

variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  sensitive   = true
}

# 직접 생성한 볼륨을 넣어주세요.
# 이 볼륨은 테라폼으로 관리하지 않습니다.
# 이는 볼륨이 실수로 인한 삭제를 방지하기 위함입니다.
variable "server_docker_volume_id" {
  description = "server_docker_volume_id"
  type        = string
  sensitive   = true
}

variable "server_docker_volume_path" {
  description = "server_docker_volume_path"
  type        = string
  sensitive   = true
}

variable "server_docker_volume_mount_path" {
  description = "server_docker_volume_mount_path"
  type        = string
}

variable "server_instance_type" {
  description = "server_instance_type"
  type        = string
}

variable "server_ami" {
  description = "server_ami"
  type        = string
}

variable "mysql_root_password" {
  description = "The root password for MySQL."
  type        = string
}

variable "mysql_tz" {
  description = "mysql_tz"
  type        = string
}

################################################################################
# AWS 인프라 모듈 호출
################################################################################

module "aws_infra" {
  source = "./modules/aws_infra"

  aws_region                      = var.aws_region
  aws_access_key                  = var.aws_access_key
  aws_secret_key                  = var.aws_secret_key
  server_docker_volume_id         = var.server_docker_volume_id
  server_docker_volume_path       = var.server_docker_volume_path
  server_docker_volume_mount_path = var.server_docker_volume_mount_path
  prefix                          = var.prefix
  server_instance_type            = var.server_instance_type
  terraform_env                   = var.terraform_env
}

module "aws_waiting" {
  source = "./modules/aws_waiting"

  server_public_ip = module.aws_infra.server_public_ip
  server_pem_path  = module.aws_infra.server_pem_file_path
  server_id        = module.aws_infra.server_aws_instance_id
  server_docker_volume_mount_path = var.server_docker_volume_mount_path
}

module "docker_infra" {
  source = "./modules/docker_infra"

  server_public_ip                = module.aws_infra.server_public_ip
  server_pem_path                 = module.aws_infra.server_pem_file_path
  server_id                       = module.aws_infra.server_aws_instance_id
  server_docker_volume_mount_path = var.server_docker_volume_mount_path
  mysql_root_password             = var.mysql_root_password
  mysql_tz                        = var.mysql_tz
}