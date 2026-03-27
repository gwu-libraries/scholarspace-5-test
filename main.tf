terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  # terraform init -migrate-state -backend-config=backend.hcl
  backend "s3" {}

  required_version = ">= 1.2.0"
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

variable "aws_region" {
  description = "AWS region for all resources"
  default     = "us-east-1"
  type        = string
}

variable "aws_access_key" {
  type      = string
  default   = null
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  default   = null
  sensitive = true
}

variable "vpc_cidr" {
  description = "CIDR block for production VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for production subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH access. Leave empty to disable SSH ingress."
  type        = list(string)
  default     = []
}

variable "aws_availability_zone" {
  description = "aws availability zone"
  default     = "us-east-1a"
  type        = string
}

variable "site_prefix" {
  description = "Prefix for naming of resources"
  default     = "scholarspace"
  type        = string
}

variable "instance_ami" {
  description = "AMI used for application instances"
  default     = "ami-020cba7c55df1f615"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type used for each environment"
  default     = "t2.small"
  type        = string
}

variable "key_name" {
  description = "Existing AWS key pair name for SSH"
  default     = "main-key"
  type        = string
}

variable "repo_clone_url" {
  description = "Repository URL cloned on instance boot"
  default     = "https://github.com/gwu-libraries/scholarspace-5-test.git"
  type        = string
}

variable "s3_bucket_name" {
  type = string
}

variable "s3_prefix" {
  type    = string
  default = ""
}

resource "aws_vpc" "app_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.site_prefix}_prod_vpc"
  }
}

resource "aws_subnet" "app_subnet" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.subnet_cidr
  availability_zone = var.aws_availability_zone

  tags = {
    Name = "${var.site_prefix}_prod_subnet"
  }
}

resource "aws_internet_gateway" "app_gateway" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "${var.site_prefix}_prod_gateway"
  }
}

resource "aws_route_table" "app_route_table" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_gateway.id
  }

  tags = {
    Name = "${var.site_prefix}_prod_route_table"
  }
}

resource "aws_route_table_association" "app_rta" {
  subnet_id      = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.app_route_table.id
}

resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic_prod"
  description = "Allow web traffic for prod"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = length(var.ssh_allowed_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web_traffic_prod"
  }
}

resource "aws_eip" "eip" {
  vpc      = true
  instance = aws_instance.web_server.id
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name = "${var.site_prefix}_prod_app_bucket"
  }
}

resource "aws_s3_bucket_versioning" "app_bucket_versioning" {
  bucket = aws_s3_bucket.app_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_bucket_encryption" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_bucket_public_access" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_instance" "web_server" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  availability_zone           = var.aws_availability_zone
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.app_subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_web_traffic.id]
  associate_public_ip_address = true

  user_data = <<-EOF
  #!/bin/bash
  set -euo pipefail

  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y git curl docker-compose-plugin

  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  usermod -aG docker ubuntu || true
  systemctl enable docker
  systemctl start docker
  timedatectl set-timezone America/New_York

  mkdir -p /opt/scholarspace
  chown -R ubuntu:ubuntu /opt/scholarspace
  cd /opt/scholarspace

  if [ ! -d scholarspace-5-test ]; then
    git clone ${var.repo_clone_url}
  fi
  cd scholarspace-5-test

  ./bin/prod
  EOF

  tags = {
    Name = "${var.site_prefix}_prod_web_server"
  }
}

output "prod_public_url" {
  description = "Public URL for prod deployment"
  value       = "http://${aws_eip.eip.public_ip}"
}

output "prod_s3_bucket_name" {
  description = "S3 bucket used by prod"
  value       = aws_s3_bucket.app_bucket.bucket
}
