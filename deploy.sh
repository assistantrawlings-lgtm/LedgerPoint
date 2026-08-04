#!/usr/bin/env bash
set -euo pipefail

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${AWS_REGION:-eu-north-1}"
BUCKET_NAME="${BUCKET_NAME:-ledgerpoint-$(date +%s | tail -c 8)}"
PREFIX="${PREFIX:-client-files}"
LOG_FILE="${LOG_FILE:-$WORKDIR/logs/audit.log}"

mkdir -p "$WORKDIR/logs"
mkdir -p "$WORKDIR/docs"

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$LOG_FILE"
}

require_aws() {
  command -v aws >/dev/null 2>&1 || { echo "AWS CLI is not installed." >&2; exit 1; }
}

require_aws

if [[ "$AWS_REGION" == "eu-north-1" ]]; then
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" > /dev/null 2>&1 || true
else
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --create-bucket-configuration "LocationConstraint=$AWS_REGION" > /dev/null 2>&1 || true
fi

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  > /dev/null

aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled \
  > /dev/null

log "Created private S3 bucket $BUCKET_NAME in $AWS_REGION"

cat > "$WORKDIR/.env" <<EOF
AWS_REGION=$AWS_REGION
BUCKET_NAME=$BUCKET_NAME
PREFIX=$PREFIX
LOG_FILE=$LOG_FILE
EOF

cat > "$WORKDIR/docs/deployment-summary.txt" <<EOF
Deployment summary
==================
Region: $AWS_REGION
Bucket: $BUCKET_NAME
Prefix: $PREFIX
Audit log: $LOG_FILE
EOF

log "Deployment complete"
echo "Deployment complete. Bucket: $BUCKET_NAME"