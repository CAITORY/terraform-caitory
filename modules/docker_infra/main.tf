################################################################################
# Version
################################################################################

terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
  }
}

################################################################################
# Variable
################################################################################

variable "server_public_ip" {
  description = "server_public_ip"
  type        = string
}

variable "server_pem_path" {
  description = "server_pem_path"
  type        = string
}

variable "server_id" {
  description = "server_id"
  type        = string
}

variable "server_docker_volume_mount_path" {
  description = "server_docker_volume_mount_path"
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
# Provider
################################################################################

provider "docker" {
  host     = "ssh://ubuntu@${var.server_public_ip}:22"
  ssh_opts = [
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=/dev/null",
    "-i", var.server_pem_path
  ]
}

################################################################################
# Docker Image
################################################################################

resource "docker_image" "nginx_proxy_manager" {
  name = "jc21/nginx-proxy-manager:latest"
}

resource "docker_image" "mysql" {
  name = "mysql:5"
}

################################################################################
# Docker Container
################################################################################

resource "docker_container" "nginx_proxy_manager" {
  image = docker_image.nginx_proxy_manager.image_id
  name  = "nginx_proxy_manager"
  network_mode = "bridge"

  ports {
    internal = 80
    external = 80
  }

  ports {
    internal = 81
    external = 81
  }

  ports {
    internal = 443
    external = 443
  }

  volumes {
    host_path = "${var.server_docker_volume_mount_path}/nginx-proxy-manager/data"
    container_path = "/data"
  }

  volumes {
    host_path = "${var.server_docker_volume_mount_path}/nginx-proxy-manager/letsencrypt"
    container_path = "/etc/letsencrypt"
  }

  restart = "unless-stopped"

  env = [
    "SERVER_INSTANCE_ID=${var.server_id}" // 서버가 종료되고 새로운 서버가 생성될 때 server_id가 변경되어 다시 작동하기 위함
  ]
}

resource "docker_container" "mysql" {
  image = docker_image.mysql.image_id
  name  = "mysql"
  network_mode = "bridge"

  ports {
    internal = 3306
    external = 3306
  }

  volumes {
    host_path      = "${var.server_docker_volume_mount_path}/mysql/data"
    container_path = "/var/lib/mysql"
  }

  restart = "unless-stopped"

  env = [
    "MYSQL_ROOT_PASSWORD=${var.mysql_root_password}",
    "TZ=${var.mysql_tz}",
    "SERVER_INSTANCE_ID=${var.server_id}" // 서버가 종료되고 새로운 서버가 생성될 때 server_id가 변경되어 다시 작동하기 위함
  ]
}

resource "null_resource" "caitory_php" {
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(self.triggers.server_pem_path)
    host        = self.triggers.server_public_ip
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "docker compose -f ${var.server_docker_volume_mount_path}/workspace/caitory_php/docker-compose.yml up -d",
    ]
  }

  provisioner "remote-exec" {
    when    = destroy
    inline = [
      "docker compose -f ${var.server_docker_volume_mount_path}/workspace/caitory_php/docker-compose.yml down",
    ]
  }

  triggers = {
    server_pem_path = var.server_pem_path
    server_instance_id = var.server_id
    server_public_ip = var.server_public_ip
  }
}
