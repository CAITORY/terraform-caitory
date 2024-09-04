################################################################################
# Version
################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.63.0"
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
  sensitive = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  sensitive = true
}

variable "server_docker_volume_id" {
  description = "server_volume_id"
  type        = string
  sensitive = true
}

variable "server_docker_volume_path" {
  description = "server_docker_volume_path"
  type        = string
}

variable "server_docker_volume_mount_path" {
  description = "server_docker_volume_mount_path"
  type        = string
}

variable "server_instance_type" {
  description = "server_instance_type"
  type        = string
}

################################################################################
# Provider
################################################################################

provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

################################################################################
# Random UUID
################################################################################

resource "random_uuid" "internal_version_uuid" {}

################################################################################
# Network
################################################################################

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.terraform_env}_${var.prefix}_vpc"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch  = true
  tags = {
    Name = "${var.terraform_env}_${var.prefix}_public_subnet_1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2c"
  map_public_ip_on_launch  = true
  tags = {
    Name = "${var.terraform_env}_${var.prefix}_public_subnet_2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.terraform_env}_${var.prefix}_igw"
  }
}

resource "aws_route_table" "public_route_table_1" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    cidr_block = "10.0.0.0/16"  # VPC의 CIDR 블록
    gateway_id = "local"
  }

  tags = {
    Name = "${var.terraform_env}_${var.prefix}_public_route_table_1"
  }
}

resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table_1.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table_1.id
}

################################################################################
# Key Pair
################################################################################

resource "tls_private_key" "key_pair_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair_public_key" {
  key_name   = "${var.terraform_env}_${var.prefix}_key_pair_public_key_version_${random_uuid.internal_version_uuid.result}"
  public_key = tls_private_key.key_pair_key.public_key_openssh
}

resource "aws_secretsmanager_secret" "key_pair_private_key" {
  name = "${var.terraform_env}_${var.prefix}_key_pair_private_key_version_${random_uuid.internal_version_uuid.result}"
}

resource "aws_secretsmanager_secret_version" "ssh_private_key_secret_version" {
  secret_id     = aws_secretsmanager_secret.key_pair_private_key.id
  secret_string = tls_private_key.key_pair_key.private_key_pem
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "server_sg" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS"
  }

  ingress {
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Nginx Proxy Manager Admin Page"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.terraform_env}_${var.prefix}_server_sg"
  }
}

################################################################################
# EC2 Instance
################################################################################

resource "aws_instance" "server" {
  ami           = "ami-05d2438ca66594916" # Ubuntu Server 24.04 LTS (HVM),EBS General Purpose (SSD) Volume Type. Support available from Canonical (http://www.ubuntu.com/cloud/services).
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_1.id
  key_name      = aws_key_pair.key_pair_public_key.key_name

  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  // user_data 작성시 서버가 다시 죽었다가 띄워지므로 사용자가 사용하지 않는 시간대에 수정이 이루어져야 합니다.
  user_data = <<-EOF
#!/bin/bash
# docker install start
sudo apt-get -y update
sudo apt-get -y install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get -y update

sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
# docker install end

# mount start
while [ ! -e ${var.server_docker_volume_path} ]; do
  echo "Waiting for volume to be attached..."
  sleep 10
done

if ! blkid ${var.server_docker_volume_path}; then
  # 파일 시스템이 없는 경우에만 포맷
  sudo mkfs.ext4 ${var.server_docker_volume_path}
fi
sudo mkdir -p ${var.server_docker_volume_mount_path}
sudo mount ${var.server_docker_volume_path} ${var.server_docker_volume_mount_path}
sudo chmod 777 ${var.server_docker_volume_mount_path}

echo "${var.server_docker_volume_path} ${var.server_docker_volume_mount_path} ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
# mount end
#
              EOF

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.terraform_env}_${var.prefix}_server"
  }

  vpc_security_group_ids = [aws_security_group.server_sg.id]
}

################################################################################
# Volume
################################################################################

resource "aws_volume_attachment" "docker_data_volume_attach" {
  device_name = var.server_docker_volume_path
  volume_id   = var.server_docker_volume_id
  instance_id = aws_instance.server.id
}

################################################################################
# SSM
################################################################################

resource "aws_iam_role" "ssm_role" {
  name = "${var.terraform_env}_${var.prefix}_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${var.terraform_env}_${var.prefix}_ssm_instance_profile"
  role = aws_iam_role.ssm_role.name
}

################################################################################
# Elastic IP
################################################################################

resource "aws_eip" "server_eip" {
}

resource "aws_eip_association" "caitory_server_eip_assoc" {
  instance_id   = aws_instance.server.id
  allocation_id = aws_eip.server_eip.id
}

################################################################################
# Locals
################################################################################

locals {
  server_key_pem_file_path = "${path.module}/server_key.pem"
}

################################################################################
# Output
################################################################################

resource "null_resource" "generate_pem" {
  provisioner "local-exec" {
    command = <<EOT
      echo "${tls_private_key.key_pair_key.private_key_pem}" > ${local.server_key_pem_file_path}
      chmod 600 ${local.server_key_pem_file_path}
    EOT
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

output "server_public_ip" {
  description = "server_public_ip"
  value       = aws_instance.server.public_ip
}

output "server_pem_file_path" {
  description = "server_pem_file_path"
  value       = local.server_key_pem_file_path
}

output "server_aws_instance_id" {
  description = "server_aws_instance_id"
  value       = aws_instance.server.id
}