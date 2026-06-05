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
  apt-get install -y git curl docker-compose-plugin awscli nfs-common

  mkdir -p /mnt/efs
  if ! mountpoint -q /mnt/efs; then
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.uploads.id}.efs.${var.aws_region}.amazonaws.com:/ /mnt/efs
  fi
  mkdir -p /mnt/efs/ocr-cache
  chown -R 1001:101 /mnt/efs/ocr-cache || true
  chmod 0775 /mnt/efs/ocr-cache || true

  if ! grep -q "${aws_efs_file_system.uploads.id}.efs.${var.aws_region}.amazonaws.com:/ /mnt/efs nfs4" /etc/fstab; then
    echo "${aws_efs_file_system.uploads.id}.efs.${var.aws_region}.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev,nofail 0 0" >> /etc/fstab
  fi

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

  upsert_env() {
    local key="$1"
    local value="$2"

    if grep -q "^$key=" .env; then
      sed -i "s|^$key=.*|$key=$value|" .env
    else
      echo "$key=$value" >> .env
    fi
  }

  # Keep EC2 console operations aligned with ECS by forcing Aurora DB settings.
  upsert_env "DB_HOST" "${aws_rds_cluster.aurora.endpoint}"
  upsert_env "DB_PORT" "5432"

  # Keep FITS endpoint aligned with ECS service discovery.
  upsert_env "FITS_SERVLET_URL" "http://${aws_service_discovery_service.fits.name}.${aws_service_discovery_private_dns_namespace.internal.name}:8080/fits"

  # Point EC2-hosted Rails at ElastiCache instead of a local Redis container.
  upsert_env "REDIS_HOST" "${aws_elasticache_replication_group.redis.primary_endpoint_address}"
  upsert_env "REDIS_PORT" "6379"
  upsert_env "REDIS_PASSWORD" ""
  upsert_env "EFS_OCR_CACHE_MOUNT" "/mnt/efs/ocr-cache"

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

resource "aws_eip" "eip" {
  vpc      = true
  instance = aws_instance.web_server.id
}
