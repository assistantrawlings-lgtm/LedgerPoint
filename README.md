# LedgerPoint Secure Cloud File Storage

This workspace contains a simple AWS S3 solution for LedgerPoint's internal file-sharing workflow.

## Design choices

- Access mechanism: time-limited presigned URLs for individual objects, rather than a public bucket. This keeps the bucket private, avoids discoverability by search engines, and ensures links expire automatically.
- Default expiry: 2880 minutes for shared links.
- Revocation: delete the object or generate a new presigned URL; the old link stops working once it expires.
- Logging: every upload, download, list, delete, and share action is written to logs/audit.log.

## Files

- deploy.sh: provisions a private S3 bucket and applies public-access blocking.
- scripts/ledgerpoint-cli.sh: Bash CLI for upload, download, list, delete, and share.
- docs/phase0-worksheet.md: design worksheet.
- docs/incident-report.md: incident report template with evidence.
- docs/deployment-summary.txt: generated deployment summary.
