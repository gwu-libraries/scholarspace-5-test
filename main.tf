terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

variable "subnet_prefix" {
  description = "cidr block for subnet"
  default     = "10.0.1.0/24"
  type        = string
}

variable "vpc_prefix" {
  description = "cidr block for vpc"
  default     = "10.0.0.0/16"
  type        = string
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

resource "aws_vpc" "prod_vpc" {
  cidr_block = var.vpc_prefix

  tags = {
    Name = "${var.site_prefix}_prod_vpc"
  }
}

resource "aws_subnet" "prod_subnet" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = var.subnet_prefix
  availability_zone = var.aws_availability_zone

  tags = {
    Name = "${var.site_prefix}_prod_subnet"
  }
}

resource "aws_internet_gateway" "prod_gateway" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "${var.site_prefix}_prod_gateway"
  }
}

resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.prod_gateway.id
  }

  tags = {
    Name = "${var.site_prefix}_prod_route_table"
  }
}

resource "aws_route_table_association" "prod_rta" {
  subnet_id      = aws_subnet.prod_subnet.id
  route_table_id = aws_route_table.prod_route_table.id
}

resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.prod_vpc.id

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

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}

resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.prod_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]
}

# this is a work around for adding a 30 second delay
# ideally would just get depends_on to work
resource "time_sleep" "delay" {
  create_duration = "30s"
  depends_on = [
    aws_network_interface.web_server_nic
  ]
}

resource "aws_eip" "eip" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  # workaround
  depends_on = [time_sleep.delay]
}

resource "aws_ecr_repository" "ecr" {
  name                 = "${var.site_prefix}_ecr"
  image_tag_mutability = "MUTABLE"

  tags = {
    Name = "${var.site_prefix}_ecr"
  }
}

resource "aws_instance" "prod_web_server" {
  ami               = "ami-0953476d60561c955"
  instance_type     = "t2.medium"
  availability_zone = var.aws_availability_zone
  key_name          = "main-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web_server_nic.id
  }

  user_data = <<-EOF
  #!/bin/bash
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo groupadd docker
  sudo usermod -aG docker ubuntu
  newgrp docker
  sudo chown $USER /var/run/docker.sock
  su -s ubuntu
  sudo systemctl enable docker
  sudo systemctl start docker

  sudo apt-get install docker-compose-plugin
  sudo timedatectl set-timezone America/New_York

  sudo apt install git

  mkdir -p /opt/scholarspace
  sudo chown -R ubuntu:ubuntu /opt/scholarspace
  cd /opt/scholarspace

  git clone https://github.com/gwu-libraries/scholarspace-5-test.git

  sudo chown -R ubuntu:ubuntu /opt/scholarspace/scholarspace-5-test

  cd /opt/scholarspace/scholarspace-5-test

  openssl req -x509 -newkey rsa:4096 -keyout /opt/scholarspace/scholarspace/nginx/certs/key.pem -out /opt/scholarspace/scholarspace/nginx/certs/certificate.pem -sha256 -days 3650 -nodes -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"

  docker compose up -d

  docker exec -d scholarspace_rails sh -c "bundle exec rails db:create; bundle exec rails db:migrate; bundle exec rails db:seed"
  EOF

  tags = {
    Name = "${var.site_prefix}_prod_web_server"
  }
}

output "server_public_ip" {
  value = aws_eip.eip.public_ip
}