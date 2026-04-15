terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  # terraform init -migrate-state -backend-config=backend.hcl
  # backend "s3" {}

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type = string
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
  type        = string
}

variable "site_prefix" {
  description = "Prefix for naming of resources"
  default     = "scholarspace"
  type        = string
}

variable "instance_ami" {
  default  = null
  type     = string
  nullable = true
}

variable "instance_type" {
  description = "EC2 instance type used for each environment"
  default     = "c7i.xlarge"
  type        = string
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size for the EC2 instance in GiB"
  default     = 80
  type        = number
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  default     = "gp3"
  type        = string
}

variable "key_name" {
  description = "Name for Terraform-managed EC2 key pair"
  default     = "scholarspace-prod-key"
  type        = string
}

variable "public_key_path" {
  description = "Absolute path to the SSH public key (.pub) used for EC2 access"
  default     = "~/.ssh/id_rsa.pub"
  type        = string
}

variable "repo_clone_url" {
  description = "Repository URL cloned on instance boot"
  default     = "https://github.com/gwu-libraries/scholarspace-5-test.git"
  type        = string
}

variable "deploy_git_ref" {
  description = "Git ref (branch/tag/sha) deployed on instance boot"
  default     = "tf-experiment"
  type        = string
}

variable "ssm_env_parameter_name" {
  description = "SSM Parameter Store name containing full .env content as SecureString"
  type        = string
}

variable "s3_bucket_name" {
  type = string
}

variable "s3_prefix" {
  type    = string
  default = ""
}

data "aws_ami" "ubuntu_amd64" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  ssm_env_parameter_arn = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trim(var.ssm_env_parameter_name, "/")}"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ec2_ssm_env_read" {
  statement {
    actions = [
      "ssm:GetParameter",
    ]
    resources = [local.ssm_env_parameter_arn]
  }
}

data "aws_iam_policy_document" "ec2_s3_access" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [aws_s3_bucket.app_bucket.arn]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.app_bucket.arn}/*"]
  }
}

resource "aws_iam_role" "web_server_role" {
  name               = "${var.site_prefix}-prod-web-server-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy" "web_server_ssm_env_read" {
  name   = "${var.site_prefix}-prod-web-server-ssm-env-read"
  role   = aws_iam_role.web_server_role.id
  policy = data.aws_iam_policy_document.ec2_ssm_env_read.json
}

resource "aws_iam_role_policy" "web_server_s3_access" {
  name   = "${var.site_prefix}-prod-web-server-s3"
  role   = aws_iam_role.web_server_role.id
  policy = data.aws_iam_policy_document.ec2_s3_access.json
}

resource "aws_iam_instance_profile" "web_server_profile" {
  name = "${var.site_prefix}-prod-web-server-profile"
  role = aws_iam_role.web_server_role.name
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

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.app_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.app_route_table.id]

  tags = {
    Name = "${var.site_prefix}_prod_s3_gateway_endpoint"
  }
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

resource "aws_key_pair" "app_key_pair" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "web_server" {
  ami                         = coalesce(var.instance_ami, data.aws_ami.ubuntu_amd64.id)
  instance_type               = var.instance_type
  availability_zone           = var.aws_availability_zone
  key_name                    = aws_key_pair.app_key_pair.key_name
  subnet_id                   = aws_subnet.app_subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_web_traffic.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.web_server_profile.name

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = var.root_volume_type
    encrypted   = true
  }

  user_data = <<-EOF
  #!/bin/bash
  set -euo pipefail

  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh
  usermod -aG docker ubuntu || true
  systemctl enable docker
  systemctl start docker
  timedatectl set-timezone America/New_York

  apt-get update
  apt-get install -y git curl docker-compose-plugin awscli

  mkdir -p /opt/scholarspace
  chown -R ubuntu:ubuntu /opt/scholarspace
  cd /opt/scholarspace

  git clone -b ${var.deploy_git_ref} ${var.repo_clone_url}
  cd scholarspace-5-test

  aws ssm get-parameter \
    --region ${var.aws_region} \
    --name "${var.ssm_env_parameter_name}" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text > .env

  chown ubuntu:ubuntu .env
  chmod 600 .env

  openssl req -x509 -newkey rsa:4096 \
    -keyout nginx/certs/key.pem \
    -out nginx/certs/certificate.pem \
    -sha256 -days 3650 -nodes \
    -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"

  bin/prod
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
