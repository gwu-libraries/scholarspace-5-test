# ── EC2 web server ────────────────────────────────────────────────────────────

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
    actions   = ["ssm:GetParameters", "ssm:GetParameter"]
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

# ── ECS task execution & task roles ──────────────────────────────────────────

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.site_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm"
}

data "aws_iam_policy_document" "ecs_task_execution_ssm" {
  statement {
    actions   = ["ssm:GetParameters", "ssm:GetParameter"]
    resources = [local.ssm_env_parameter_arn]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.ssm.target_key_arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_ssm" {
  name   = "${var.site_prefix}-ecs-task-execution-ssm"
  role   = aws_iam_role.ecs_task_execution_role.id
  policy = data.aws_iam_policy_document.ecs_task_execution_ssm.json
}

resource "aws_iam_role" "sidekiq_task_role" {
  name = "${var.site_prefix}-sidekiq-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

data "aws_iam_policy_document" "sidekiq_task_policy" {
  statement {
    actions   = ["ssm:GetParameters", "ssm:GetParameter"]
    resources = [local.ssm_env_parameter_arn]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.ssm.target_key_arn]
  }

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

  # Required for ECS Exec (rails console via aws ecs execute-command)
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "sidekiq_task_policy" {
  name   = "${var.site_prefix}-sidekiq-task-policy"
  role   = aws_iam_role.sidekiq_task_role.id
  policy = data.aws_iam_policy_document.sidekiq_task_policy.json
}
