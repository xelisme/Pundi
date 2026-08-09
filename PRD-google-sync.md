# PRD: Google Account Sync for HyperBudget

## Problem Statement

HyperBudget currently stores all data (categories, transactions, history) locally in SharedPreferences. This means:

1. Data is lost if the user clears app data or switches devices
2. No way to access budget data from multiple devices
3. No backup mechanism — a factory reset means starting from zero
4. The user has requested the ability to synchronize data via their Google account

## Solution

Add Google Sign-In authentication and Firestore cloud synchronization so that all budget data (categories, transactions, history) persists to the cloud, tied to the user's Google account. Data syncs automatically across devices.

## User Stories

1. As a user, I want to sign in with my Google account, so that my data is tied to a persistent identity
2. As a user, I want to sign in using a single tap on a "Masuk dengan Google" button, so that onboarding is effortless
3. As a user, I want to see my profile name, email, and photo after signing in, so that I know which account is active
4. As a user, I want my existing local data (categories + transactions) to automatically upload to the cloud when I first sign in, so that I don't lose what I've already recorded
5. As a user, I want my categories to sync to the cloud, so that I can use the same category setup on another device
6. As a user, I want my transaction history to sync to the cloud, so that I can review past spending on any device
7. As a user, I want data to sync automatically in the background, so that I don't have to manually press a "sync" button
8. As a user, I want the app to work offline and sync when connectivity returns, so that I'm not blocked by poor network conditions
9. As a user, I want to sign out from the settings screen, so that I can switch accounts or disconnect
10. As a user, I want a clear indication of my sync status (last synced time), so that I know my data is up to date
11. As a user, I want my allocation categories (name, percentage, color, icon, description) to persist across devices, so that my budget setup is consistent
12. As a user, I want my transaction records (amount, type, splits, merchant, items, date) to persist across devices, so that my financial history is complete
13. As a user, I want category balance calculations to work correctly with cloud-synced data, so that I see accurate per-category summaries
14. As a user, I want the monthly summary view to reflect cloud-synced data, so that I can review any month's breakdown on any device
15. As a user, I want the home screen's "Total Keseluruhan" card to show grand totals from all synced data, so that I have an at-a-glance net worth view
16. As a user, I want to be shown a login screen if I'm not authenticated, so that data is always protected
17. As a user, I want my session to persist across app restarts (stay signed in), so that I don't have to log in every time
18. As a user, I want a sign-out confirmation dialog, so that I don't accidentally disconnect
19. As a user, I want the app to gracefully handle Firestore errors (network timeout, permission denied), so that I'm informed but not blocked
20. As a user, I want CSV export to still work with cloud-synced data, so that I can share my financial data externally

## Implementation Decisions

### Architecture

- **Firebase as backend**: Use Firebase Auth (Google provider) + Cloud Firestore for data persistence
- **Offline-first**: Firestore SDK provides built-in offline persistence on mobile — reads are served from cache when offline, writes are queued and flushed when connectivity returns
- **Document structure**: User-scoped collections under `users/{uid}/` with subcollections `categories/` and `transactions/`
- **Local + Remote dual write**: BudgetRepository writes to both SharedPreferences (local cache) and Firestore (cloud) on every mutation. Reads prefer Firestore when online, fall back to local when offline.

### Firestore Document Shape

Categories and transactions will use their existing `toJson()` serialization. The Firestore document ID will be the existing UUID (not auto-generated Firestore IDs) to avoid ID mapping issues.

```
users/{uid}/
  categories/{categoryId}     — AllocationCategory JSON
  transactions/{transactionId} — TransactionRecord JSON
```

### Authentication Flow

- App starts → check auth state → if signed in, load data from Firestore; if not, show login screen
- Login screen has single "Masuk dengan Google" button
- After successful sign-in, check if user has existing Firestore data; if not, migrate local SharedPreferences data to Firestore
- Auth state persists via Firebase Auth's built-in session management

### Data Migration Strategy

On first sign-in after adding cloud sync:
1. Read existing SharedPreferences data (categories + history)
2. If Firestore has no data for this user, write local data to Firestore
3. If Firestore already has data (returning user on new device), skip migration and load from Firestore
4. After migration, subsequent reads always come from Firestore

### Repository Refactoring

The current `BudgetRepository` is a monolith (ChangeNotifier + storage + business logic). Minimal refactoring approach:

- Add `FirestoreService` as a dependency injected into `BudgetRepository`
- Each write method (`recordTransaction`, `addCategory`, etc.) calls both local save and Firestore save
- Add `syncFromFirestore()` method that pulls all Firestore docs and updates local state
- `init()` gains an optional `userId` parameter — when provided, it sets up Firestore listeners instead of just reading SharedPreferences
- Keep the ChangeNotifier pattern — UI layer stays unchanged

### Settings Screen Updates

- Display user profile (photo, name, email) at top of settings
- Add "Keluar" (Sign Out) button with confirmation dialog
- Show last sync timestamp
- Existing export/import features remain functional

### Dependencies

```
firebase_core: ^3.12.0
firebase_auth: ^5.5.1
cloud_firestore: ^5.6.5
google_sign_in: ^6.2.2
```

### Platform Configuration

- `android/app/build.gradle.kts`: Add `com.google.gms.google-services` plugin
- `android/build.gradle.kts`: Add `com.google.gms:google-services` classpath
- `android/app/google-services.json`: Firebase project config (user must create Firebase project)
- iOS: `GoogleService-Info.plist` + CocoaPods setup

### Security Rules

Firestore rules enforce user-scoped access:

```
match /users/{userId} {
  match /categories/{catId} {
    allow read, write: if request.auth != null && request.auth.uid == userId;
  }
  match /transactions/{txnId} {
    allow read, write: if request.auth != null && request.auth.uid == userId;
  }
}
```

## Testing Decisions

- **Auth flow testing**: Test sign-in → data load → sign-out → sign-in cycle to verify data persists across sessions
- **Offline behavior**: Test airplane mode → add transaction → restore connectivity → verify Firestore sync
- **Migration testing**: Clear Firestore data → sign in with existing local data → verify upload
- **Multi-device simulation**: Sign in on device A with data → sign in on device B → verify data appears
- **Error handling**: Test with invalid Firebase config, network errors, permission denied scenarios
- **Regression**: Verify all existing features (income parsing, category splits, export, history) still work with cloud-backed data
- **No unit test framework currently in project** — testing will be manual APK builds on device/emulator

## Out of Scope

- Multi-user / family shared budgets
- Real-time multi-device conflict resolution (last-write-wins for now)
- Bank account linking or automatic transaction import
- Push notifications for budget alerts
- Data encryption at rest beyond Firestore's default encryption
- Web or desktop sync (mobile-only for this phase)
- Rollback or version history of transactions
- Budget forecasting or predictive analytics

## Further Notes

- The existing `PRODUCT.md` explicitly marks "Cloud sync (local storage only)" as out of scope — this PRD overrides that for the sync feature specifically
- Indonesian UI copy convention should be maintained (e.g., "Masuk dengan Google", "Keluar", "Terakhir disinkronkan")
- The app's luxury minimal design aesthetic should be preserved in the login screen and settings updates
- Google Fonts (Inter + Lora) and the warm monochrome color palette (AppColors) should be used consistently in new screens
