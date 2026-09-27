# SplitMate — Smart Expense Tracker

<p align="center">
  <img src="assets/App icon.png" width="90" />
</p>

<p align="center">
  <b>Personal + Group expense tracking, offline-first, SaaS-ready.</b><br/>
  Flutter • Firebase • Hive • Riverpod
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter" />
  <img src="https://img.shields.io/badge/Firebase-Spark-FFCA28?logo=firebase" />
  <img src="https://img.shields.io/badge/State-Riverpod-0175C2" />
  <img src="https://img.shields.io/badge/Storage-Hive-FF6B35" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-000?logo=flutter" />
</p>

---

## Why SplitMate

Most trackers do personal *or* split. SplitMate does both in one offline-first app — personal logs, group splits with settlement, monthly budgets with 80%/100% alerts, PDF reports, and private sync. Built to feel native on Android, iOS and Web from one codebase.

## Features

- **Personal & Group modes** with toggle
- **Group splits** — create groups, invite by email, `settledBy` per-member tracking
- **Smart Budgets** — per-category monthly limits, progress bars, warning/over-budget banners (replaced legacy parent-monitoring card)
- **Offline-first + auto-sync** — Hive cache, Firestore `lastWriteWins` via `updatedAt`, `ProviderScope` + `budgetsProvider` live updates
- **PDF monthly reports** — emoji-safe (NotoSans fallback), share/open via `SharePlus`
- **Secure by default** — `firestore.rules` tenant isolation (`users/{uid}` own only, `groups` members only, `group_expenses` splitBetween only), `AppCheck` (Play Integrity / DeviceCheck / ReCaptcha test key), API keys restricted in GCP
- **Web & iOS ready** — `kIsWeb` guards, `ReCaptchaV3Provider` for web, `Info.plist` camera/photo permissions for iOS

## Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Framework | Flutter 3.10+ / Dart 3 | Cross-platform |
| Backend | Firebase Auth, Firestore, AppCheck (Spark free tier) | No server to manage |
| Local DB | Hive (`personal_expenses`, `group_expenses`, `user_profile`, `settings`, `budgets`, `notification_status`) | Offline, <10ms reads |
| State | `flutter_riverpod` `2.6.1`, `StateNotifier` for budgets/expenses | Compile-safe, testable |
| UI | `fl_chart`, `shimmer`, `AppTheme` glass + light theme | Consistent design system |
| PDF/Share | `pdf`, `printing`, `share_plus`, `path_provider` | Reports + backup JSON |

## Project Structure

```
lib/
  main.dart                         # ProviderScope + AppCheck + Hive init + AuthWrapper (single restore)
  firebase_options.dart              # (gitignored) -> use firebase_options.example template
  core/{config,error,utils}         # AppConstants, Failure, currency/date validators
  data/{models,datasources,repositories} # Budget (typeId 4), HiveService, BudgetRepository
  domain/{entities,repositories,usecases}
  presentation/{providers,widgets}  # budgetsProvider, BudgetInsightsCard/Dialog, ShimmerCard
  theme/app_theme.dart              # dark glass + light theme, glassDecoration helper
  screens/{login,signup,profile,groups,reports,notification,...}
  SplitMateHomeScreen.dart          # Home with BudgetAlertBanner + MonthlySummary charts
firebase.json / firestore.rules / firestore.indexes.json
```

## Development Model

**Agile, incremental, SaaS-grade.** We work in vertical slices, each slice is `code -> flutter analyze --fatal-infos -> flutter test -> manual run` before next. 

- **Sprint 1 — Foundation:** Align `firebase_*` to `3.x/5.x`, remove dead deps (`sqflite`, `uni_links2`, `timer_button`), add Riverpod, guard `kIsWeb`.
- **Sprint 2 — Data:** Introduce `Budget` Hive model, `HiveService`/`BudgetRepository`, fix `firestore_sync_service` `clear()` -> merge `lastWriteWins` with `updatedAt`/`synced`.
- **Sprint 3 — Feature:** Replace `Parent Monitor` card with `Budget Insights` + `BudgetAlertBanner`, emoji-safe PDF via `_sanitizeForPdf`.
- **Sprint 4 — Security:** `firestore.rules` fail-closed, composite indexes, AppCheck, budget validation `1-10M`, iOS `Info.plist` permissions.
- **Sprint 5 — Quality:** `Share` -> `SharePlus.instance`, file-name lint, `shimmer` skeletons, unit tests `budget_test 4/4`, `analyze` from 11 -> 2 issues, `build web` + `build apk` green.

Quality gates: `flutter analyze` 0 errors, `flutter test` 5/5, manual check on Android + Chrome.

## Getting Started

### Prerequisites

- Flutter `>=3.10.0`, Dart `>=3.0.0`
- Firebase project (Spark free tier is enough)

### 1. Clone & install

```bash
git clone https://github.com/AyushShende2679/splitmate.git
cd splitmate
flutter pub get
```

### 2. Configure Firebase (keys are not committed)

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID
# creates lib/firebase_options.dart, android/app/google-services.json, ios/Runner/GoogleService-Info.plist
```

Or copy `lib/firebase_options.dart.example` -> `lib/firebase_options.dart` and fill `YOUR_*` placeholders.

On GCP Console restrict the Web API key to `*.googleapis.com` + your bundle ID / domain, and enable AppCheck (Play Integrity for Android, DeviceCheck for iOS, ReCaptcha for Web with test key `6LeIxAcT...` already in `main.dart`).

### 3. Run

```bash
flutter run               # Android/iOS
flutter run -d chrome     # Web
flutter test              # 5 tests
flutter analyze           # expect 2 low issues (intentional)
```

### 4. Build

```bash
flutter build apk --release   # -> build/app/outputs/flutter-apk/app-release.apk (~61 MB)
flutter build web --debug
```

## Firestore Rules & Indexes

Deployed via `firebase.json`:

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

Rules enforce: users own their doc, groups members-only, `group_expenses` readable only by `splitBetween`. See `firestore.rules`.

## Security Notes

- `lib/firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist` are gitignored. Commit only the `.example` template.
- Web API key is public by Firebase design; protection comes from `firestore.rules` + `AppCheck` + GCP API restrictions, not hiding the key.
- No `cloud_functions` — keeps Spark free.

## Roadmap

- 5.1 Recurring/subscription tracker
- 5.2 Savings goals vaults
- 5.3 Family shared wallet (opt-in, aggregated stats only)

## License

MIT © 2025 Ayush Shende
