resource "aws_efs_access_point" "solr_data" {
  file_system_id = aws_efs_file_system.uploads.id

  lifecycle {
    prevent_destroy = true
  }

  posix_user {
    uid = 8983
    gid = 8983
  }

  root_directory {
    path = "/solr-data"

    creation_info {
      owner_gid   = 8983
      owner_uid   = 8983
      permissions = "0775"
    }
  }

  tags = {
    Name = "${var.site_prefix}-solr-data-access-point"
  }
}