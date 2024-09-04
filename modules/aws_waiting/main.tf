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

################################################################################
# Null Resource
################################################################################

// docker가 설치될 때까지 대기
resource "null_resource" "wait_for_docker" {
  provisioner "remote-exec" {
    inline = [
      "while ! systemctl is-active --quiet docker; do echo 'Waiting for Docker service...'; sleep 10; done",
      "echo 'Docker service is now active.'",
      "sleep 120"  # Docker 서비스가 활성화된 후 2분 대기
    ]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(self.triggers.server_pem_path)
    host        = var.server_public_ip
    timeout = "10m"
  }

  triggers = {
    server_pem_path = var.server_pem_path
    server_id = var.server_id
  }
}

// docker volume이 mount가 될 때까지 대기
resource "null_resource" "wait_for_mount" {
  provisioner "remote-exec" {
    inline = [
      "while ! mount | grep -q '${var.server_docker_volume_mount_path}'; do echo 'Waiting for volume to be mounted...'; sleep 10; done",
      "echo 'Volume is successfully mounted at ${var.server_docker_volume_mount_path}'",
      "sleep 60"
    ]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(self.triggers.server_pem_path)
    host        = var.server_public_ip
    timeout     = "10m"
  }

  triggers = {
    server_pem_path = var.server_pem_path
    server_id       = var.server_id
  }
}