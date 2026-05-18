resource "aws_efs_file_system" "uploads" {
  creation_token = "${var.site_prefix}-uploads"
  encrypted      = true

  tags = {
    Name = "${var.site_prefix}-uploads"
  }
}

resource "aws_efs_access_point" "uploads" {
  file_system_id = aws_efs_file_system.uploads.id

  posix_user {
    uid = 1001
    gid = 101
  }

  root_directory {
    path = "/uploads"

    creation_info {
      owner_gid   = 101
      owner_uid   = 1001
      permissions = "0775"
    }
  }

  tags = {
    Name = "${var.site_prefix}-uploads-access-point"
  }
}

resource "aws_security_group" "efs_uploads" {
  name        = "${var.site_prefix}-efs-uploads"
  description = "Allow ECS tasks to mount shared upload EFS"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description     = "Allow Rails web ECS tasks to mount EFS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tasks.id]
  }

  ingress {
    description     = "Allow Sidekiq ECS tasks to mount EFS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.sidekiq_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.site_prefix}-efs-uploads"
  }
}

resource "aws_efs_mount_target" "uploads_primary" {
  file_system_id  = aws_efs_file_system.uploads.id
  subnet_id       = aws_subnet.app_private_subnet.id
  security_groups = [aws_security_group.efs_uploads.id]
}

resource "aws_efs_mount_target" "uploads_secondary" {
  file_system_id  = aws_efs_file_system.uploads.id
  subnet_id       = aws_subnet.app_private_subnet_secondary.id
  security_groups = [aws_security_group.efs_uploads.id]
}

resource "aws_efs_access_point" "ocr_cache" {
  file_system_id = aws_efs_file_system.uploads.id

  posix_user {
    uid = 1001
    gid = 101
  }

  root_directory {
    path = "/ocr-cache"

    creation_info {
      owner_gid   = 101
      owner_uid   = 1001
      permissions = "0775"
    }
  }

  tags = {
    Name = "${var.site_prefix}-ocr-cache-access-point"
  }
}

resource "aws_security_group_rule" "efs_from_ec2" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs_uploads.id
  source_security_group_id = aws_security_group.allow_web_traffic.id
  description              = "Allow EC2 instance to mount EFS for OCR cache"
}
