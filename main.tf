################################################################################
# Version
################################################################################

terraform {
  required_version = "~> 1.9.0"

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

variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

################################################################################
# Provider
################################################################################

provider "aws" {
  region = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

################################################################################
# Network
################################################################################

resource "aws_vpc" "caitory_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "caitory_vpc"
  }
}

resource "aws_subnet" "caitory_public_subnet_1" {
  vpc_id            = aws_vpc.caitory_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "caitory_public_subnet_1"
  }
}

resource "aws_subnet" "caitory_public_subnet_2" {
  vpc_id            = aws_vpc.caitory_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "caitory_public_subnet_2"
  }
}

resource "aws_internet_gateway" "caitory_igw" {
  vpc_id = aws_vpc.caitory_vpc.id
}

resource "aws_route_table" "caitory_public_route_table" {
  vpc_id = aws_vpc.caitory_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.caitory_igw.id
  }
}

resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.caitory_public_subnet_1.id
  route_table_id = aws_route_table.caitory_public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.caitory_public_subnet_2.id
  route_table_id = aws_route_table.caitory_public_route_table.id
}