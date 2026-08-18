# Google Spreadsheet Sync - Migration from Drive

This document records the migration from Google Drive sync to Google Spreadsheet sync in BudgetAI.

## Current State

We migrated from Google Drive sync (which was not persisting data correctly) to **Google Spreadsheet sync** using the `googleapis/sheets/v4.dart` API. The app now stores all budget data (categories + transactions) as JSON in a single cell of a Google Spreadsheet named "BudgetAI".

### Key Changes

- **`lib/services/sheets_service.dart`**: New service replacing `drive_service.dart`. Uses `googleapis/sheets/v4.dart` to read/write data to a Google Spreadsheet.
- **`lib/services/auth_service.dart`**: OAuth scope changed from `drive.file` to `spreadsheets`.
- **`lib/repositories/budget_repository.dart`**: Updated to use `SheetsService` instead of `DriveService`.
- **`lib/main.dart`**: Updated to instantiate `SheetsService` and provide it via Provider.
- **`lib/screens/settings_screen.dart`**: Updated UI text to say "Google Spreadsheet" instead of "Google Drive".

### How It Works

1. On first login, the app creates a Google Spreadsheet named "BudgetAI" with a sheet named "BudgetData".
2. The spreadsheet ID is stored in SharedPreferences for future access.
3. All data (categories + transactions) is stored as a JSON string in cell A1 of the "BudgetData" sheet.
4. On sync, the app reads the remote data and merges it with local data using timestamp-based conflict resolution.
5. The app supports pull-to-refresh from the history screen for bidirectional sync.

---

## Manual Console Steps Remaining

After deploying the code changes, the following manual steps must be completed in Google Cloud Console:

### 1. Enable Google Sheets API

- Go to [Google Cloud Console API Library](https://console.cloud.google.com/apis/library)
- Select project `budgetai-7145b`
- Search for "Google Sheets API"
- Click "Enable" if not already enabled

### 2. Add Sheets Scope to OAuth Consent Screen

- Go to [APIs & Services → OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)
- Select project `budgetai-7145b`
- Click "Edit App"
- In "Scopes" section, click "Add or Remove Scopes"
- Add scope: `https://www.googleapis.com/auth/spreadsheets`
- Save changes

### 3. Test User Configuration (if app is in Testing status)

- In OAuth consent screen, verify test users are added under "Test users"
- Only test users can authorize the app while in Testing status

### 4. Verify OAuth Credentials

- Go to [APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials)
- Ensure OAuth 2.0 Client IDs exist for your platforms (Web, Android, iOS)
- Download/verify `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) match the project

---

## Data Format

The spreadsheet stores data in the following JSON format:

```json
{
  "timestamp": 1234567890,
  "categories": [
    {
      "id": "uuid",
      "name": "Tabungan",
      "percentage": 50.0,
      "colorHex": "#3B82F6",
      "iconName": "savings",
      "description": "Tabungan & Dana Darurat"
    }
  ],
  "history": [
    {
      "id": "uuid",
      "timestamp": 1234567890,
      "rawInput": "input text",
      "totalAmount": 100000,
      "splits": [...],
      "type": "expense",
      "merchantName": "Store Name",
      "items": "Item list",
      "receiptDate": 1234567890,
      "chargedTo": "Tabungan"
    }
  ]
}
```
