resource "aws_efs_access_point" "derivatives_cache" {
  file_system_id = aws_efs_file_system.uploads.id

  lifecycle {
    prevent_destroy = true
  }

  posix_user {
    uid = 1001
    gid = 101
  }

  root_directory {
    path = "/derivatives-cache"

    creation_info {
      owner_gid   = 101
      owner_uid   = 1001
      permissions = "0775"
    }
  }

  tags = {
    Name = "${var.site_prefix}-derivatives-cache-access-point"
  }
}