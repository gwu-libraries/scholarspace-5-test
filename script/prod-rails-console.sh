#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"
TFVARS_FILE="${TFVARS_FILE:-${TERRAFORM_DIR}/terraform.tfvars}"

if [[ ! -d "${TERRAFORM_DIR}" ]]; then
  echo "Terraform directory not found: ${TERRAFORM_DIR}" >&2
  exit 1
fi

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

if [[ ! -f "${TFVARS_FILE}" ]]; then
  echo "terraform.tfvars not found: ${TFVARS_FILE}" >&2
  exit 1
fi

AWS_REGION="${AWS_REGION:-$(get_tfvars_value aws_region "${TFVARS_FILE}")}"
if [[ -z "${AWS_REGION:-}" ]]; then
  echo "AWS_REGION is not set. Export AWS_REGION or define aws_region in ${TFVARS_FILE}." >&2
  exit 1
fi

CLUSTER="${CLUSTER:-$(terraform -chdir="${TERRAFORM_DIR}" output -raw sidekiq_ecs_cluster_name)}"
WEB_SERVICE="${WEB_SERVICE:-$(terraform -chdir="${TERRAFORM_DIR}" output -raw web_ecs_service_name)}"
CONTAINER="${CONTAINER:-web}"
RAILS_ROOT="${RAILS_ROOT:-/app/scholarspace}"

TASK_ARN="$(aws ecs list-tasks \
  --region "${AWS_REGION}" \
  --cluster "${CLUSTER}" \
  --service-name "${WEB_SERVICE}" \
  --desired-status RUNNING \
  --query 'taskArns[0]' \
  --output text)"

if [[ -z "${TASK_ARN}" || "${TASK_ARN}" == "None" ]]; then
  echo "No running web task found for service: ${WEB_SERVICE}" >&2
  exit 1
fi

echo "Opening Rails console in ${WEB_SERVICE} (${TASK_ARN})..." >&2

aws ecs execute-command \
  --region "${AWS_REGION}" \
  --cluster "${CLUSTER}" \
  --task "${TASK_ARN}" \
  --container "${CONTAINER}" \
  --interactive \
  --command "/bin/sh -lc 'cd ${RAILS_ROOT} && bundle exec rails c'"