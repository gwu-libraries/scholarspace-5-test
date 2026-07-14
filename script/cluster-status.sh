#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_ROOT/terraform"

CLUSTER="$(terraform -chdir="$TERRAFORM_DIR" output -raw sidekiq_ecs_cluster_name)"
SITE_PREFIX="$(awk -F' = ' '/^site_prefix[[:space:]]*=/{gsub(/\"/, "", $2); print $2; exit}' "$TERRAFORM_DIR/terraform.tfvars")"
AWS_REGION="$(aws configure get region)"
SERVICES=(
  "${SITE_PREFIX}-web"
  "${SITE_PREFIX}-fits"
  "${SITE_PREFIX}-fedora"
  "${SITE_PREFIX}-solr"
  "${SITE_PREFIX}-memcached"
  "${SITE_PREFIX}-sidekiq-default"
  "${SITE_PREFIX}-sidekiq-whisper"
  "${SITE_PREFIX}-sidekiq-ocr_text"
  "${SITE_PREFIX}-sidekiq-derivatives"
  "${SITE_PREFIX}-sidekiq-thumbnail"
)

aws ecs describe-services \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER" \
  --services "${SERVICES[@]}" \
  --query 'services[].{Service:serviceName,Running:runningCount,Desired:desiredCount,Status:status,PrimaryRolloutState:deployments[?status==`PRIMARY`]|[0].rolloutState,PrimaryRolloutReason:deployments[?status==`PRIMARY`]|[0].rolloutStateReason,PrimaryTaskDef:deployments[?status==`PRIMARY`]|[0].taskDefinition}' \
  --output table