## Attachments (R2) smoke test

### Prereqs
- Backend env:
  - `S3_BUCKET_NAME` set
  - `S3_ENDPOINT_URL` set to your R2 S3 endpoint (example: `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`)
  - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` set to an R2 API token pair
  - `AWS_REGION` can be anything, but when the endpoint contains `.r2.cloudflarestorage.com` the backend will use region `auto`
- Run migrations (includes `000009_add_attachments.*.sql`)

### Steps
1) In the app (debug builds), open a household hub screen and tap the **cloud upload** icon in the top app bar.
2) Confirm you see a snackbar like `Uploaded attachment <id>`.
3) In the backend logs you should see successful requests for:
   - `POST /api/v1/attachments/upload-intent`
   - `POST /api/v1/attachments/{id}/finalize`
4) In your R2 bucket, verify an object exists at:
   - `groups/<groupId>/attachments/<attachmentId>/diagnostic.txt`

