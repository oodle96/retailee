# Cloud Run web prototype

This container serves the Google-connected Flutter web build on port 8080.

From the repository root:

```powershell
flutter pub get
flutter build web --release --dart-define-from-file=config/google.local.json --output=build/cloudrun-web
New-Item -ItemType Directory -Force deploy/web/public
Copy-Item build/cloudrun-web/* deploy/web/public/ -Recurse -Force
gcloud run deploy retailee-web --source deploy/web --project YOUR_PROJECT --region asia-southeast2 --allow-unauthenticated --port 8080 --memory 256Mi --min-instances 0 --max-instances 2
```

Set `FIREBASE_WEB_APP_ID` in your ignored local configuration to your Firebase web registration. Add the deployed host to Firebase Authentication authorized domains and its HTTPS origin to the backend `ALLOWED_ORIGINS`, preserving existing entries. Firebase web configuration is included in the browser build by design; never add service-account keys or backend secrets to Flutter build definitions.

The `public/` directory is generated and excluded from Git. Only that build and the nginx configuration are uploaded as the frontend container. The app continues to use the separate authenticated Cloud Run API, Firestore and Firebase Storage.
