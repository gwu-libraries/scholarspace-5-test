#!/usr/bin/env bash
set -euo pipefail

# Fast path for app-only deploys:
# 1) Build/push web image once using registry cache.
# 2) Re-tag sidekiq image to same digest (no second build).
# 3) Register new ECS task definitions with the new tag.
# 4) Update services and wait for stability.

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd aws
require_cmd docker
require_cmd jq

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <tag>" >&2
  echo "Example: $0 2026-05-08-hotfix-1" >&2
  exit 1
fi

TAG="$1"
AWS_REGION="${AWS_REGION:-us-west-2}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-417560131410}"
SITE_PREFIX="${SITE_PREFIX:-scholarspace-tf-test-ab}"
CLUSTER_NAME="${CLUSTER_NAME:-${SITE_PREFIX}-sidekiq}"

WEB_SERVICE_NAME="${WEB_SERVICE_NAME:-${SITE_PREFIX}-web}"
SIDEKIQ_DEFAULT_SERVICE_NAME="${SIDEKIQ_DEFAULT_SERVICE_NAME:-${SITE_PREFIX}-sidekiq-default}"
SIDEKIQ_WHISPER_SERVICE_NAME="${SIDEKIQ_WHISPER_SERVICE_NAME:-${SITE_PREFIX}-sidekiq-whisper}"

WEB_CONTAINER_NAME="${WEB_CONTAINER_NAME:-web}"
SIDEKIQ_DEFAULT_CONTAINER_NAME="${SIDEKIQ_DEFAULT_CONTAINER_NAME:-sidekiq-default}"
SIDEKIQ_WHISPER_CONTAINER_NAME="${SIDEKIQ_WHISPER_CONTAINER_NAME:-sidekiq-whisper}"

WEB_REPO="${WEB_REPO:-${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SITE_PREFIX}-web}"
SIDEKIQ_REPO="${SIDEKIQ_REPO:-${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${SITE_PREFIX}-sidekiq}"

WEB_IMAGE="${WEB_REPO}:${TAG}"
SIDEKIQ_IMAGE="${SIDEKIQ_REPO}:${TAG}"
BUILD_CACHE_REF="${WEB_REPO}:buildcache"

update_service_task_definition() {
  local service_name="$1"
  local container_name="$2"
  local new_image="$3"

  local current_td_arn
  current_td_arn="$(aws ecs describe-services \
    --region "$AWS_REGION" \
    --cluster "$CLUSTER_NAME" \
    --services "$service_name" \
    --query 'services[0].taskDefinition' \
    --output text)"

  local task_def_json
  task_def_json="$(aws ecs describe-task-definition \
    --region "$AWS_REGION" \
    --task-definition "$current_td_arn" \
    --query 'taskDefinition' \
    --output json)"

  local updated_payload
  updated_payload="$(echo "$task_def_json" | jq \
    --arg container "$container_name" \
    --arg image "$new_image" \
    '
      del(
        .taskDefinitionArn,
        .revision,
        .status,
        .requiresAttributes,
        .compatibilities,
        .registeredAt,
        .registeredBy
      )
      | .containerDefinitions |=
          map(if .name == $container then .image = $image else . end)
      ')"

  local new_td_arn
  new_td_arn="$(aws ecs register-task-definition \
    --region "$AWS_REGION" \
    --cli-input-json "$updated_payload" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)"

  aws ecs update-service \
    --region "$AWS_REGION" \
    --cluster "$CLUSTER_NAME" \
    --service "$service_name" \
    --task-definition "$new_td_arn" \
    >/dev/null

  echo "Updated ${service_name} -> ${new_td_arn}"
}

echo "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" >/dev/null

echo "Building and pushing ${WEB_IMAGE} (with registry cache)..."
docker buildx build \
  --platform linux/amd64 \
  --build-arg BUILD_ENV=prod \
  --cache-from "type=registry,ref=${BUILD_CACHE_REF}" \
  --cache-to "type=registry,ref=${BUILD_CACHE_REF},mode=max" \
  -f Dockerfile \
  -t "$WEB_IMAGE" \
  --push \
  .

echo "Tagging sidekiq image to same digest without rebuild: ${SIDEKIQ_IMAGE}"
docker buildx imagetools create -t "$SIDEKIQ_IMAGE" "$WEB_IMAGE" >/dev/null

echo "Updating ECS task definitions/services..."
update_service_task_definition "$WEB_SERVICE_NAME" "$WEB_CONTAINER_NAME" "$WEB_IMAGE"
update_service_task_definition "$SIDEKIQ_DEFAULT_SERVICE_NAME" "$SIDEKIQ_DEFAULT_CONTAINER_NAME" "$SIDEKIQ_IMAGE"
update_service_task_definition "$SIDEKIQ_WHISPER_SERVICE_NAME" "$SIDEKIQ_WHISPER_CONTAINER_NAME" "$SIDEKIQ_IMAGE"

echo "Waiting for ECS services to stabilize..."
aws ecs wait services-stable \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --services "$WEB_SERVICE_NAME" "$SIDEKIQ_DEFAULT_SERVICE_NAME" "$SIDEKIQ_WHISPER_SERVICE_NAME"

echo "Done. Services are stable on tag ${TAG}."
