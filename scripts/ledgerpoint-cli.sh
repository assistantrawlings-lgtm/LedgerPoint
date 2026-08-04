#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# LedgerPoint Secure Cloud File Storage CLI
# Usage: ./storage.sh <upload|download|list|delete|share|revoke> [args...]
# ---------------------------------------------------------------------------

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
ENV_FILE="$WORKDIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
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

require_aws() {
  command -v aws >/dev/null 2>&1 || { echo "AWS CLI is not installed." >&2; exit 1; }
}

object_key() {
  local blob="$1"
  if [[ "$blob" == "$PREFIX/"* ]]; then
    echo "$blob"
  else
    echo "$PREFIX/$blob"
  fi
}

# Confirms an object actually exists in the bucket before acting on it.
# Prevents confusing AWS CLI errors and gives a clear, consistent message instead.
object_exists() {
  local key="$1"
  aws s3api head-object --bucket "$BUCKET_NAME" --key "$key" --region "$AWS_REGION" >/dev/null 2>&1
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
  if ! object_exists "$key"; then
    echo "No such file in storage: $key" >&2
    exit 1
  fi
  aws s3 cp "s3://$BUCKET_NAME/$key" "$dest" --region "$AWS_REGION" --only-show-errors
  log "DOWNLOAD $key by $(whoami)"
  echo "Downloaded s3://$BUCKET_NAME/$key to $dest"
}

cmd_list() {
  require_bucket
  local result
  # --output text prints the literal word "None" when there are zero matches,
  # since the JMESPath query returns null. Handle that explicitly so the CLI
  # gives a clear, honest message instead of a confusing "None".
  result=$(aws s3api list-objects-v2 \
    --bucket "$BUCKET_NAME" \
    --prefix "$PREFIX/" \
    --region "$AWS_REGION" \
    --query 'Contents[].Key' \
    --output text)
  log "LIST by $(whoami)"
  if [[ -z "$result" || "$result" == "None" ]]; then
    echo "No files found under $PREFIX/"
  else
    echo "$result" | tr '\t' '\n'
  fi
}

cmd_delete() {
  local blob="$1"
  require_bucket
  local key
  key=$(object_key "$blob")
  if ! object_exists "$key"; then
    echo "No such file in storage: $key" >&2
    exit 1
  fi
  aws s3 rm "s3://$BUCKET_NAME/$key" --region "$AWS_REGION" --only-show-errors
  log "DELETE $key by $(whoami)"
  echo "Deleted s3://$BUCKET_NAME/$key"
}

cmd_share() {
  local blob="$1"
  local expiry_minutes="${2:-2880}"
  require_bucket

  if ! [[ "$expiry_minutes" =~ ^[0-9]+$ ]] || [[ "$expiry_minutes" -le 0 ]]; then
    echo "Expiry must be a positive whole number of minutes. Got: $expiry_minutes" >&2
    exit 1
  fi

  local key
  key=$(object_key "$blob")
  if ! object_exists "$key"; then
    echo "No such file in storage: $key" >&2
    exit 1
  fi

  local url
  url=$(aws s3 presign "s3://$BUCKET_NAME/$key" --region "$AWS_REGION" --expires-in "$((expiry_minutes * 60))")
  log "SHARE $key expiry_minutes=$expiry_minutes by $(whoami)"
  echo "$url"
}

cmd_revoke() {
  local blob="$1"
  require_bucket
  local key
  key=$(object_key "$blob")
  if ! object_exists "$key"; then
    echo "No such file in storage: $key" >&2
    exit 1
  fi
  local ts
  ts=$(date -u +'%Y%m%dT%H%M%SZ')
  local new_key="revoked/${ts}-$(basename "$key")"
  aws s3 mv "s3://$BUCKET_NAME/$key" "s3://$BUCKET_NAME/$new_key" --region "$AWS_REGION" --only-show-errors
  log "REVOKE $key -> $new_key by $(whoami)"
  echo "Revoked. Any existing share link for $blob is now dead (moved to $new_key)."
}

usage() {
  cat >&2 <<EOF
Usage: $0 <command> [args...]

Commands:
  upload   <local-file-path> <blob-name>        Upload a file
  download <blob-name> <local-dest-path>        Download a file
  list                                          List all files under the prefix
  delete   <blob-name>                          Delete a file permanently
  share    <blob-name> [expiry-minutes=2880]     Generate a time-limited share link (default 48h)
  revoke   <blob-name>                          Kill any outstanding share link for a file
EOF
}

main() {
  require_aws
  local cmd="${1:-help}"
  case "$cmd" in
    upload)
      [[ $# -eq 3 ]] || { usage; exit 1; }
      cmd_upload "$2" "$3"
      ;;
    download)
      [[ $# -eq 3 ]] || { usage; exit 1; }
      cmd_download "$2" "$3"
      ;;
    list)
      [[ $# -eq 1 ]] || { usage; exit 1; }
      cmd_list
      ;;
    delete)
      [[ $# -eq 2 ]] || { usage; exit 1; }
      cmd_delete "$2"
      ;;
    share)
      [[ $# -eq 2 || $# -eq 3 ]] || { usage; exit 1; }
      cmd_share "$2" "${3:-2880}"
      ;;
    revoke)
      [[ $# -eq 2 ]] || { usage; exit 1; }
      cmd_revoke "$2"
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