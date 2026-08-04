#!/usr/bin/env bash
set -euo pipefail

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
ENV_FILE="$WORKDIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

AWS_REGION="${AWS_REGION:-eu-north-1}"
BUCKET_NAME="${BUCKET_NAME:-}"
PREFIX="${PREFIX:-client-files}"
LOG_FILE="${LOG_FILE:-$WORKDIR/logs/audit.log}"

mkdir -p "$WORKDIR/logs"
mkdir -p "$WORKDIR/docs"

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$LOG_FILE"
}

require_bucket() {
  if [[ -z "$BUCKET_NAME" ]]; then
    echo "S3 bucket is not set. Run deploy.sh first." >&2
    exit 1
  fi
}

object_key() {
  local blob="$1"
  if [[ "$blob" == "$PREFIX/"* ]]; then
    echo "$blob"
  else
    echo "$PREFIX/$blob"
  fi
}

cmd_upload() {
  local src="$1"
  local blob="$2"
  require_bucket
  [[ -f "$src" ]] || { echo "File not found: $src" >&2; exit 1; }
  local key
  key=$(object_key "$blob")
  aws s3 cp "$src" "s3://$BUCKET_NAME/$key" --region "$AWS_REGION" --only-show-errors
  log "UPLOAD $key by $(whoami)"
  echo "Uploaded $src to s3://$BUCKET_NAME/$key"
}

cmd_download() {
  local blob="$1"
  local dest="$2"
  require_bucket
  local key
  key=$(object_key "$blob")
  aws s3 cp "s3://$BUCKET_NAME/$key" "$dest" --region "$AWS_REGION" --only-show-errors
  log "DOWNLOAD $key by $(whoami)"
  echo "Downloaded s3://$BUCKET_NAME/$key to $dest"
}

cmd_list() {
  require_bucket
  aws s3api list-objects-v2 --bucket "$BUCKET_NAME" --prefix "$PREFIX/" --query 'Contents[].Key' --output text
  log "LIST by $(whoami)"
}

cmd_delete() {
  local blob="$1"
  require_bucket
  local key
  key=$(object_key "$blob")
  aws s3 rm "s3://$BUCKET_NAME/$key" --region "$AWS_REGION" --only-show-errors
  log "DELETE $key by $(whoami)"
  echo "Deleted s3://$BUCKET_NAME/$key"
}

cmd_share() {
  local blob="$1"
  local expiry_minutes="${2:-60}"
  require_bucket
  local key
  key=$(object_key "$blob")
  local url
  url=$(aws s3 presign "s3://$BUCKET_NAME/$key" --region "$AWS_REGION" --expires-in "$((expiry_minutes * 60))")
  log "SHARE $key expiry=$expiry_minutes by $(whoami)"
  echo "$url"
}

usage() {
  echo "Usage: $0 <upload|download|list|delete|share> [args...]" >&2
}

main() {
  case "${1:-help}" in
    upload)
      cmd_upload "$2" "$3"
      ;;
    download)
      cmd_download "$2" "$3"
      ;;
    list)
      cmd_list
      ;;
    delete)
      cmd_delete "$2"
      ;;
    share)
      cmd_share "$2" "$3"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
