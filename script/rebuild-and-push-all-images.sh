#!/usr/bin/env bash
set -euo pipefail

# Rebuilds and pushes all runtime images used by this stack, using one timestamp tag.
# Run with --update-tfvars to insert the new image tag to terraform.tfvars for deployment

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd aws
require_cmd docker
require_cmd date
require_cmd awk

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-${REPO_ROOT}/terraform}"
TFVARS_FILE="${TFVARS_FILE:-${TERRAFORM_DIR}/terraform.tfvars}"

if [[ ! -d "$TERRAFORM_DIR" ]]; then
  echo "Terraform directory not found: $TERRAFORM_DIR" >&2
  exit 1
fi

usage() {
  cat <<EOF
Usage: $0 [--update-tfvars] [--tag <tag>]

Options:
  --update-tfvars   Update image URI keys in terraform.tfvars after push.
  --tag <tag>       Use a specific tag instead of generating a timestamp tag.
  -h, --help        Show this help message.

Environment overrides:
  AWS_REGION, AWS_ACCOUNT_ID, SITE_PREFIX, TERRAFORM_DIR, TFVARS_FILE
EOF
}

UPDATE_TFVARS=false
CUSTOM_TAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update-tfvars)
      UPDATE_TFVARS=true
      shift
      ;;
    --tag)
      if [[ -z "${2:-}" ]]; then
        echo "Missing value for --tag" >&2
        exit 1
      fi
      CUSTOM_TAG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

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

upsert_tfvars_string() {
  local key="$1"
  local value="$2"
  local file_path="$3"
  local tmp
  tmp="$(mktemp)"

  if awk -F'=' -v k="$key" '$0 ~ "^[[:space:]]*" k "[[:space:]]*=" { found=1 } END { exit(found ? 0 : 1) }' "$file_path"; then
    awk -F'=' -v k="$key" -v v="$value" '
      $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
        print k " = \"" v "\""
        next
      }
      { print }
    ' "$file_path" > "$tmp"
  else
    cat "$file_path" > "$tmp"
    printf '\n%s = "%s"\n' "$key" "$value" >> "$tmp"
  fi

  mv "$tmp" "$file_path"
}

ensure_ecr_repo_exists() {
  local repo_name="$1"

  if ! aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$repo_name" >/dev/null 2>&1; then
    echo "Missing ECR repository: $repo_name" >&2
    echo "Create Terraform-managed repos first:" >&2
    echo "  cd ${TERRAFORM_DIR}" >&2
    echo "  terraform apply -target=aws_ecr_repository.app" >&2
    exit 1
  fi
}

AWS_REGION="${AWS_REGION:-$(aws configure get region)}"
if [[ -z "$AWS_REGION" ]]; then
  echo "AWS region is empty. Set AWS_REGION or run 'aws configure' first." >&2
  exit 1
fi

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
if [[ -z "$AWS_ACCOUNT_ID" ]]; then
  echo "AWS account id is empty. Set AWS_ACCOUNT_ID or authenticate AWS CLI first." >&2
  exit 1
fi

if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "terraform.tfvars not found: $TFVARS_FILE" >&2
  exit 1
fi

SITE_PREFIX="${SITE_PREFIX:-$(get_tfvars_value site_prefix "$TFVARS_FILE")}"
if [[ -z "$SITE_PREFIX" ]]; then
  echo "site_prefix is empty in $TFVARS_FILE. Set SITE_PREFIX or define site_prefix." >&2
  exit 1
fi

APP_REPO="${SITE_PREFIX}"
APP_ECR="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_REPO}"

TAG="${CUSTOM_TAG:-$(date +%Y%m%d-%H%M%S)}"
WEB_IMAGE_URI="${APP_ECR}:${TAG}-web"
SIDEKIQ_DEFAULT_IMAGE_URI="${APP_ECR}:${TAG}-sidekiq-default"
SIDEKIQ_WHISPER_IMAGE_URI="${APP_ECR}:${TAG}-sidekiq-whisper"
SIDEKIQ_OCR_TEXT_IMAGE_URI="${APP_ECR}:${TAG}-sidekiq-ocr-text"
FITS_IMAGE_URI="${APP_ECR}:${TAG}-fits"
SOLR_IMAGE_URI="${APP_ECR}:${TAG}-solr"

assert_tag_exists() {
  local repo_name="$1"
  local tag_name="$2"

  aws ecr describe-images \
    --region "$AWS_REGION" \
    --repository-name "$repo_name" \
    --image-ids "imageTag=${tag_name}" \
    >/dev/null
}

echo "APP_ECR=$APP_ECR"
echo "WEB_IMAGE_URI=$WEB_IMAGE_URI"
echo "SIDEKIQ_DEFAULT_IMAGE_URI=$SIDEKIQ_DEFAULT_IMAGE_URI"
echo "SIDEKIQ_WHISPER_IMAGE_URI=$SIDEKIQ_WHISPER_IMAGE_URI"
echo "SIDEKIQ_OCR_TEXT_IMAGE_URI=$SIDEKIQ_OCR_TEXT_IMAGE_URI"
echo "FITS_IMAGE_URI=$FITS_IMAGE_URI"
echo "SOLR_IMAGE_URI=$SOLR_IMAGE_URI"
echo "TAG=$TAG"
echo "SITE_PREFIX=$SITE_PREFIX"

echo "Checking Terraform-managed ECR repository exists..."
ensure_ecr_repo_exists "$APP_REPO"

echo "Authenticating Docker to ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" >/dev/null

echo "Building and pushing web image..."
docker buildx build \
  --platform linux/amd64 \
  --build-arg BUILD_ENV=prod \
  --target scholarspace-web-prod \
  -f "${REPO_ROOT}/Dockerfile" \
  -t "${WEB_IMAGE_URI}" \
  --push \
  "$REPO_ROOT"

echo "Building and pushing sidekiq default image..."
docker buildx build \
  --platform linux/amd64 \
  --build-arg BUILD_ENV=prod \
  --target scholarspace-sidekiq-default-prod \
  -f "${REPO_ROOT}/Dockerfile" \
  -t "${SIDEKIQ_DEFAULT_IMAGE_URI}" \
  --push \
  "$REPO_ROOT"

echo "Building and pushing sidekiq whisper image..."
docker buildx build \
  --platform linux/amd64 \
  --build-arg BUILD_ENV=prod \
  --target scholarspace-sidekiq-whisper-prod \
  -f "${REPO_ROOT}/Dockerfile" \
  -t "${SIDEKIQ_WHISPER_IMAGE_URI}" \
  --push \
  "$REPO_ROOT"

echo "Building and pushing sidekiq ocr-text image..."
docker buildx build \
  --platform linux/amd64 \
  --build-arg BUILD_ENV=prod \
  --target scholarspace-sidekiq-ocr-text-prod \
  -f "${REPO_ROOT}/Dockerfile" \
  -t "${SIDEKIQ_OCR_TEXT_IMAGE_URI}" \
  --push \
  "$REPO_ROOT"

echo "Building and pushing fits image..."
docker buildx build \
  --platform linux/amd64 \
  -f "${REPO_ROOT}/Dockerfile-fits" \
  -t "${FITS_IMAGE_URI}" \
  --push \
  "$REPO_ROOT"

echo "Building and pushing solr image..."
docker buildx build \
  --platform linux/amd64 \
  -f "${REPO_ROOT}/Dockerfile-solr" \
  -t "${SOLR_IMAGE_URI}" \
  --push \
  "$REPO_ROOT"

echo "Verifying pushed tags in ECR..."
assert_tag_exists "$APP_REPO" "${TAG}-web"
assert_tag_exists "$APP_REPO" "${TAG}-sidekiq-default"
assert_tag_exists "$APP_REPO" "${TAG}-sidekiq-whisper"
assert_tag_exists "$APP_REPO" "${TAG}-sidekiq-ocr-text"
assert_tag_exists "$APP_REPO" "${TAG}-fits"
assert_tag_exists "$APP_REPO" "${TAG}-solr"

echo "All images built and pushed successfully."
echo "Use this tag in terraform.tfvars image values: $TAG"
echo "IMAGE_TAG=$TAG"

if [[ "$UPDATE_TFVARS" == true ]]; then
  echo "Updating image URIs in $TFVARS_FILE..."
  upsert_tfvars_string web_image "${WEB_IMAGE_URI}" "$TFVARS_FILE"
  upsert_tfvars_string sidekiq_default_image "${SIDEKIQ_DEFAULT_IMAGE_URI}" "$TFVARS_FILE"
  upsert_tfvars_string sidekiq_whisper_image "${SIDEKIQ_WHISPER_IMAGE_URI}" "$TFVARS_FILE"
  upsert_tfvars_string sidekiq_ocr_text_image "${SIDEKIQ_OCR_TEXT_IMAGE_URI}" "$TFVARS_FILE"
  upsert_tfvars_string fits_image "${FITS_IMAGE_URI}" "$TFVARS_FILE"
  upsert_tfvars_string solr_image "${SOLR_IMAGE_URI}" "$TFVARS_FILE"
  echo "terraform.tfvars image URIs updated."
fi
