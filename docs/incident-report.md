# Incident Report

## Symptom

An expired share link was expected to fail, but the proof was collected by requesting the object with the expired presigned URL and observing the denial response from AWS S3.

## Investigation trail

1. Ran the share command to generate a presigned URL.
2. Waited for the link to expire.
3. Sent the request to the object URL and observed the HTTP error response.
4. Reviewed the local audit log to confirm the share event had been recorded.

## Root cause

The share link was intentionally time-limited, so the request failed once the presigned URL expiry passed. The denial was expected and confirms the design is enforcing expiry rather than leaving access open indefinitely.

## Fix

The implementation uses a short-lived presigned URL for sharing and records each share event in the audit log. The proof of the fix is the denied response after expiry, plus the related log entry.

## Design reflection

The Phase 0 design made the failure easier to catch because the access mechanism was explicitly time-bounded and the audit log recorded each sharing action. If I were to improve the design, I would add a small helper that shows the remaining validity window and automatically warns the operator before the link expires.
