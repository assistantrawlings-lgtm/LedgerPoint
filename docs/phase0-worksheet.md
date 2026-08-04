# Phase 0: Design Worksheet

## 2.1 Access mechanism decision

We will use AWS S3 with a private bucket and time-limited presigned URLs for individual objects.

Why this fits the requirement:
- The bucket remains private by default, so files are not publicly discoverable.
- A presigned URL is signed and time-bounded, so it is not easy to guess or keep open indefinitely.
- A shared link expires automatically, so access does not remain indefinite.

Alternative considered: public bucket or public object access. This was rejected because it would expose the entire bucket and would conflict with the requirement that files remain private and not be discoverable.

## 2.2 Expiry and revocation policy

- Default share link lifetime: 60 minutes.
- Revocation approach: if access must be revoked early, the object can be deleted or replaced so the old presigned URL becomes unusable; the office manager can also stop using the link and rotate the file if necessary.

## 2.3 Logging plan

| Action | What gets logged | Where it is stored | Who can read the log |
| --- | --- | --- | --- |
| Upload | timestamp, user, object key, action | local file logs/audit.log | operator / office manager |
| Download | timestamp, user, object key, action | local file logs/audit.log | operator / office manager |
| Share | timestamp, user, object key, expiry, action | local file logs/audit.log | operator / office manager |
| Delete | timestamp, user, object key, action | local file logs/audit.log | operator / office manager |

## Build note

The implementation uses presigned URL sharing and private bucket access as planned.
