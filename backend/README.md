# Retailee API: Cloud Run + Gemini on Vertex AI

`POST /v1/business-understanding` reviews a business profile and clarification answers before setup completes. It returns a summary, goods/services/mixed mode, pricing unit, material-use flag and up to three questions. The owner confirms the result. Service businesses using consumables remain services; mixed means both merchandise and services are sold.

`serviceIncome` extraction reads completed services with service charges, per-line units and explicit direct costs. The app requires completion confirmation, supports owner-selected material usage and never treats customer-owned items as merchandise.

`POST /v1/extract` turns a photo into a draft. The app requires review and explicit confirmation before posting business data. The backend normalizes model output and checks amounts.

`POST /v1/personalize` returns Indonesian business advice for retail, food, laundry, shoe/bag cleaning, beauty, repair, general services, home production and other businesses. It uses the owner's profile, supplied aggregate facts and feedback. Recommendations must reference supplied fact IDs; numeric prose and unknown evidence references are rejected. The client displays exact saved fact values alongside advice. This endpoint shares the extraction endpoint's Firebase authentication and rate limiter.

## Authentication

Production requires `FIREBASE_PROJECT_ID`. Each request sends `Authorization: Bearer <Firebase ID token>` and the API verifies its signature, audience, and expiry using Firebase Admin. Rate limits use the verified owner UID. The Cloud Run service is publicly reachable so Firebase-authenticated clients can call it; extraction itself requires a valid token.

Vertex AI uses the service account attached to Cloud Run. No Gemini API key or service-account JSON key is put in the app.

## Deploy

Prerequisites: Google Cloud CLI login, a Firebase/Google Cloud project with billing enabled, the relevant APIs, and permission to deploy and grant the runtime service account Vertex AI access.

From the workspace in PowerShell:

```powershell
.\backend\deploy.ps1 -ProjectId hackacthon-7ec2e -AllowedOrigins @('https://hackacthon-7ec2e.web.app','https://hackacthon-7ec2e.firebaseapp.com','http://localhost:8085')
```

The script uses explicit project flags, creates the runtime service account when absent, grants `roles/aiplatform.user`, deploys to `asia-southeast2`, and saves `AI_ENDPOINT` to the matching local app configuration. It stops on a failed command. The default model is `gemini-3.8-flash` at the global Vertex endpoint; `-GeminiModel` and `-GeminiLocation` override these.

Cloud Run scales to zero, with at most three configured instances. Browser origins must be explicitly listed. `/health` reports server readiness and model configuration; it does not call Gemini or prove that extraction or advice generation works. The legacy `/healthz` alias remains available locally, but Cloud Run reserves some paths ending in `z`, so use `/health` for deployed checks. See [Cloud Run reserved URL paths](https://docs.cloud.google.com/run/docs/known-issues#reserved-url-paths).

## App

```powershell
.\run-google.ps1
```

This loads `config/google.local.json`. The Android Google registration is installed. Browser runs also need a registered Firebase web app and `FIREBASE_WEB_APP_ID`; use port 8085 for the configured localhost origin.

## Local fake backend

```powershell
cd backend
npm.cmd run dev:fake
```

The fake backend runs on port 8080 and explicitly enables shared-key development auth (`dev-key`). A client without Firebase enabled can use `AI_ENDPOINT=http://10.0.2.2:8080` on the Android emulator and `AI_APP_KEY=dev-key`. Fake output is demonstration data, not image recognition.

## Limits

- In-memory per-owner limit: 20 extractions per minute per instance, not a global quota.
- Application request body limit: 10 MB, including base64 overhead.
- Cloud backup is a versioned 800 KB owner snapshot, not a multi-user server-side accounting ledger.
- Original photos are stored in Firebase Storage under owner/document paths, with a 6 MB photo limit. The Flutter app uploads photos before extraction and recovers uploaded photos after a restart. An interrupted upload cannot be recovered from the cloud until completed.
- Logs omit source photos, note contents, model output, and raw model error text.
