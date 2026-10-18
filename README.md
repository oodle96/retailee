# Retailee 1.3.4

Android-first record keeping and Gemini advice for Indonesian micro-businesses.

**Live web prototype:** https://retailee-web-197857328513.asia-southeast2.run.app

The web interface is hosted on Google Cloud Run and connects to Firebase sign-in, owner-scoped storage, and the Gemini backend. Sign in with your own Google account to create your business profile. See [web deployment instructions](deploy/web/README.md).

## Hackathon source and local setup

Built by Pranexia One for the Google Cloud AI Builder Cup. This repository contains the Flutter app, the Cloud Run backend, Firebase access rules, and configuration templates. The app supports English and Indonesian.

To run your own Google-connected copy:

1. Install Flutter with Dart 3.12.2 or newer, an Android SDK, Node.js 20 or newer, and the Google Cloud CLI.
2. Create a Firebase project, enable Google sign-in, Firestore and Storage, and register Android package `com.pranexia.warungpilot` with your signing certificate fingerprints. Register a web app too if you need the browser version.
3. Download your Android Firebase configuration to `android/app/google-services.json`. Copy `config/google.example.json` to `config/google.local.json` and fill in your Firebase app values and Google web client ID. These local configuration files are intentionally excluded from Git.
4. Deploy the backend using [the backend instructions](backend/README.md), with your project ID and browser origins. Put its URL in `AI_ENDPOINT` in your local configuration.
5. Deploy the supplied `firestore.rules` and `storage.rules` to your own Firebase project.
6. From the repository root, run:

```sh
flutter pub get
flutter run --dart-define-from-file=config/google.local.json
```

For an Android APK:

```sh
flutter build apk --release --dart-define-from-file=config/google.local.json
```

The current Android build uses a development signing key. Configure your own release signing for distribution; never commit signing keys. Cloud billing and Vertex AI access are required for real Gemini responses. Local demo mode and the backend fake mode do not demonstrate live Gemini functionality.

Local QA records, pitch working files, generated builds and private configuration are not included in this public source repository. References to `qa/` below describe local development records, not published benchmark evidence.

The core experience is photo capture, owner review, confirmed journaling, and advice based on that owner's records. Home prioritizes photo capture and advice; the Journal holds drafts, confirmed source documents, and other recorded income and expenses. Business type, goals, language and feedback personalize advice.

## Business setup

Setup offers selling goods, providing services, or goods and services together. A separate “Not sure? Describe your business” helper lets Gemini clarify the activities. There is no Others category in this first choice.

The owner describes what customers pay for, materials used and how work happens. Gemini asks clarification questions when needed, then the owner confirms its understanding before it is saved. Confirmed activities control service versus goods capture, stock tools, and advice context. Using supplies does not make a service business a goods seller. Existing accounts retain their records; edit the profile through Beranda > Pengaturan > Profil & jenis usaha.

| Activity | Supporting tools |
|---|---|
| Buy and resell goods | Products, purchase costs, stock and confirmed sales |
| Provide services | Completed services, charges, direct costs and consumable usage |
| Goods & services | The tools for both activities |

Industry details such as shoe cleaning, laundry or food remain part of the personalized profile. Production and recipe tools are hidden; legacy records are retained and legacy production profiles use finished-goods selling. Each product has its own unit (for example, one product in pcs and another in pack). Photo review preserves written units, and a conflicting unit must be corrected before posting to an existing product. This does not add package conversions or alternate units for one product.

The bottom tabs are Beranda, Jurnal, Foto, Laporan and Misi. Supporting stock and operational tools are available through Settings > Stok & alat usaha. These are secondary tools, not the primary onboarding or daily flow. Existing records are retained. Service catalog names, prices and costs are entered by the owner; no example prices are inserted into real records.

## Gemini personalization

Beranda > Minta arahan Gemini sends the business profile and confirmed aggregate facts for the last thirty calendar days. Up to four item summaries include recorded revenue, quantity, known cost, current stock, the owner's minimum stock and recent/previous seven-day recorded quantities. The context also includes recorded-day counts, up to three service offerings, three saleable products, three expense categories, current order balances and recent feedback. Item units are retained; missing recording days do not establish zero demand. Customer names and condition photos are not included in this advice request. Optional business descriptions are sent as entered.

Gemini prioritizes actions about named products and services: restocking, margin review, cash flow or relevant sales experiments. Recording reminders are secondary, and the habit topic is excluded when business evidence exists. Bundle ideas are experiments rather than claims of existing demand; internal supplies are not assumed to be merchandise. Each recommendation references input facts. Numeric amounts are displayed from those facts; exact catalog names may retain digits. Missing costs remain unknown and do not block stock or customer suggestions.

After a document is confirmed and saved, connected accounts request updated advice in the background. Advice failure does not undo the journal. Responses for an older context are discarded and refreshed when records changed during generation. Other profile/record changes show the existing refresh notice. Old cached advice from before this policy is cleared when loading the app. Feedback can be viewed or reset in Personalisasi & masukan. This uses context and feedback, not private model training.

Advice never posts transactions. Photo extraction creates drafts for mandatory review and confirmation. Orders are entered manually; this release does not OCR service tickets.

## Operational rules

- Unfinished orders can be revised, including scope, diagnosis, costs and schedule. Repair revisions require renewed customer approval before further work.
- Completing the last stage records order revenue once and consumes the selected materials. Service quantity itself does not consume a stock product.
- Deposits, payments and refunds are separate records. An order can finish with an outstanding balance. Cancellation requires refunding any deposit first.
- Prices on an order include what the customer owes for materials. Direct cost excludes selected materials and separately recorded overhead, preventing double counting when entered correctly.
- Materials can be marked as raw materials/consumables with no selling price. They cannot be posted as direct goods sales.
- Existing production records remain stored for compatibility; new setup does not offer recipe workflows. Waste reduces stock and records known cost as an expense.
- Unknown direct/material costs keep the resulting profit incomplete. An explicit zero is accepted only when the owner enters it.
- Missions use actual saved records and the confirmed selling/service activities.

## Google connection

Project: `hackacthon-7ec2e`. Firebase Authentication provides Google sign-in. Firestore stores an owner-scoped, versioned JSON backup. Cloud Storage stores private original document/condition photos. Cloud Run authenticates Firebase ID tokens and calls Gemini on Vertex AI using its service account; no Gemini secret is embedded in the APK.

Local configuration is in the ignored `config/google.local.json`. Run with `./run-google.ps1`, or build:

```powershell
$env:PUB_CACHE = 'D:\pub-cache'
D:\flutter\bin\flutter.bat build apk --release --dart-define-from-file=config/google.local.json
```

Deploy the backend with `./backend/deploy.ps1 -ProjectId hackacthon-7ec2e` and the intended browser origins. The browser version needs its own Firebase web app registration. Runs without Google build definitions use the local demo configuration.

## Current limits and validation

This is a single-owner app with a versioned backup, not collaborative real-time accounting. Each account's cloud snapshot is limited to 800 KB. Conflicting device updates are rejected and can be resolved through explicit cloud restore. Photo uploads are limited to 6 MB; interrupted uploads may require reselecting a photo.

Payment records do not move money or send reminders. Appointment records do not create Google Calendar events. No tax reporting, payroll, marketplace synchronization or payment gateway is included.

The user confirmed that the previous Google-connected app worked. For this release, Flutter analysis and backend compilation passed; test suites and a full device click-through were not run at the user's request. Deployment verification and the APK build record are in `qa/sme-release.json`. Prior QA files describe earlier versions and do not verify these new workflows.

## Code map

- `lib/business_types.dart`: business templates and workflow stages.
- `lib/operations_models.dart`: services, orders, payments, recipes, batches and waste.
- `lib/services/business_operations.dart`: operational posting, business context and advice feedback.
- `lib/services/ledger.dart`: financial calculations.
- `lib/services/store.dart`: persistence, records, posting, missions and backup coordination.
- `lib/screens/business_setup_screen.dart`: first setup and business profile editing.
- `lib/screens/business_home_screen.dart`: business dashboard, Gemini advice and entry points.
- `lib/screens/core_home_screen.dart`: active photo-first home, journal shortcuts, advice and daily summary.
- `lib/screens/journal_screen.dart`: draft/confirmed journal, source-document links and other financial entries.
- `lib/screens/operations_screen.dart`: orders, services, materials and production.
- `backend/src/personalization.ts`: business-specific Gemini instructions and evidence validation.
