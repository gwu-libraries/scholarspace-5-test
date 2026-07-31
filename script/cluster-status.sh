#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_ROOT/terraform"
TFVARS_FILE="${TFVARS_FILE:-$TERRAFORM_DIR/terraform.tfvars}"

get_tfvars_value() {
  local key="$1"
  local file_path="$2"
  awk -F'=' -v k="$key" '
    $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
      v = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      gsub(/"/, "", v)
      print v
      exit
    }
  ' "$file_path"
}

if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "terraform.tfvars not found: $TFVARS_FILE" >&2
  exit 1
fi

AWS_REGION="${AWS_REGION:-$(get_tfvars_value aws_region "$TFVARS_FILE")}"
if [[ -z "${AWS_REGION:-}" ]]; then
  echo "AWS_REGION is not set. Define aws_region in $TFVARS_FILE." >&2
  exit 1
fi

CLUSTER="$(terraform -chdir="$TERRAFORM_DIR" output -raw sidekiq_ecs_cluster_name)"
SITE_PREFIX="$(get_tfvars_value site_prefix "$TFVARS_FILE")"
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
  --region "${AWS_REGION}" \
  --cluster "$CLUSTER" \
  --services "${SERVICES[@]}" \
  --query 'services[].{Service:serviceName,Running:runningCount,Desired:desiredCount,Status:status,PrimaryRolloutState:deployments[?status==`PRIMARY`]|[0].rolloutState,PrimaryRolloutReason:deployments[?status==`PRIMARY`]|[0].rolloutStateReason,PrimaryTaskDef:deployments[?status==`PRIMARY`]|[0].taskDefinition}' \
  --output table