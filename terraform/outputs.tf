output "prod_public_url" {
  description = "Public URL for prod deployment"
  value       = "http://${aws_eip.eip.public_ip}"
}

output "prod_s3_bucket_name" {
  description = "S3 bucket used by prod"
  value       = aws_s3_bucket.app_bucket.bucket
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.scholarspace.dns_name
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.scholarspace.arn
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.scholarspace.arn
}

output "sidekiq_ecr_repository_url" {
  description = "ECR repository URL for Sidekiq images"
  value       = aws_ecr_repository.sidekiq.repository_url
}

output "sidekiq_ecs_cluster_name" {
  description = "ECS cluster name for Sidekiq workers"
  value       = aws_ecs_cluster.sidekiq.name
}

output "web_ecr_repository_url" {
  description = "ECR repository URL for Rails web images"
  value       = aws_ecr_repository.web.repository_url
}

output "web_ecs_service_name" {
  description = "ECS service name for Rails web"
  value       = aws_ecs_service.web.name
}

output "fits_ecr_repository_url" {
  description = "ECR repository URL for FITS images"
  value       = aws_ecr_repository.fits.repository_url
}

output "fits_ecs_service_name" {
  description = "ECS service name for FITS"
  value       = aws_ecs_service.fits.name
}

output "fits_internal_host" {
  description = "Private DNS host used by ECS services to reach FITS"
  value       = "${aws_service_discovery_service.fits.name}.${aws_service_discovery_private_dns_namespace.internal.name}"
}

output "aurora_writer_endpoint" {
  description = "Aurora cluster writer endpoint (use as DB_HOST)"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora cluster reader endpoint (optional read-only connections)"
  value       = aws_rds_cluster.aurora.reader_endpoint
}
