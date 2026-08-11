# Google Drive Sync Blocker & Future Investigation

This document records the current state of the Google Drive sync issue in BudgetAI (formerly HyperBudget) and outlines how to troubleshoot and fix it in the future.

## Current State

We migrated the project from the deprecated `google_sign_in_all_platforms` package to the official `google_sign_in` package combined with `firebase_auth` for secure email/password and Google authentication.

We temporarily migrated to **Cloud Firestore** for cloud sync, but since deploying Firestore security rules via the CLI requires the **Firebase Blaze (billing) plan**, and the goal is to keep the app **free forever** on the Spark plan, we reverted back to **Google Drive Sync**.

Currently, the Google Drive sync code is restored and compiles successfully, but **data is not persisting or syncing correctly between login/logout sessions**.

---

## Technical Setup

- **`lib/services/drive_service.dart`**: Implements the Drive sync logic using `googleapis/drive/v3.dart`. It requests an authenticated HTTP client from `AuthService` and attempts to find/create a folder named `BudgetAI` containing a `data.json` file.
- **`lib/services/auth_service.dart`**: Uses Firebase Auth and Google Sign-In. It exposes `authenticatedClient` using the stored OAuth `accessToken`.
- **`lib/repositories/budget_repository.dart`**: Integrates with `DriveService`. When the user logs in, it calls `loadFromCloud()`. On any local change (adding/updating categories or transactions), it calls `_saveToCloud()`.

---

## Symptoms & Investigation Notes

1. **OAuth Scopes Mismatch**:
   Firebase Auth Google Sign-In by default only requests the `email` and `profile` scopes. However, `DriveService` needs `https://www.googleapis.com/auth/drive.appdata` or `https://www.googleapis.com/auth/drive.file` to read/write files.
   - *Current scope config*: `GoogleSignIn(scopes: ['email'])` in `auth_service.dart`.
   - *Fix attempt*: Add `'https://www.googleapis.com/auth/drive.appdata'` or `'https://www.googleapis.com/auth/drive.file'` to the `scopes` list in the `GoogleSignIn` constructor.
   
2. **Google Cloud Console OAuth Consent Screen**:
   If scopes are added to the Flutter app, they must also be configured in the **Google Cloud Console** under APIs & Services → OAuth Consent Screen for the project `budgetai-7145b`.
   - If the project is in "Testing" status, only added test users can authorize it.
   - If the requested scopes are restricted (like `drive.file`), the app might display a "Google hasn't verified this app" warning or throw a `DEVELOPER_ERROR` if not correctly configured.

3. **Firebase Auth Token vs Google OAuth Access Token**:
   `AuthService` captures the access token from the initial Google Sign-In flow:
   ```dart
   final GoogleSignInAuthentication gAuth = await gUser.authentication;
   _accessToken = gAuth.accessToken;
   ```
   This token is valid for 1 hour. If the app is closed and reopened, Firebase Auth restores the session (`_auth.currentUser`), but `_accessToken` will be `null` because `GoogleSignIn` is not re-authenticated.
   - *Fix needed*: In `init()`, if `_auth.currentUser` is present, call `_googleSignIn.signInSilently()` to refresh the Google OAuth credentials and capture a fresh `accessToken`.

---

## Step-by-Step Troubleshooting Guide

When resuming work on the sync feature:

1. **Update Scopes in `auth_service.dart`**:
   Change the `GoogleSignIn` initialization to include the Drive scope:
   ```dart
   final GoogleSignIn _googleSignIn = GoogleSignIn(
     scopes: [
       'email',
       'https://www.googleapis.com/auth/drive.file', // For writing data.json in user's Drive
     ],
   );
   ```

2. **Add Scopes in Google Cloud Console**:
   Go to [Google Cloud Console](https://console.cloud.google.com/), select `budgetai-7145b`, and add the `https://www.googleapis.com/auth/drive.file` scope to the OAuth Consent Screen.

3. **Implement Silent Sign-In Token Refresh**:
   In `auth_service.dart`'s `init()` method, handle restoring the Google Sign-In session if the user is already authenticated with Firebase:
   ```dart
   Future<void> init() async {
     _isInitializing = true;
     notifyListeners();

     _auth.authStateChanges().listen((User? user) async {
       _user = user;
       if (user != null && _accessToken == null) {
         // Attempt silent sign-in to get Google OAuth tokens
         try {
           final gUser = await _googleSignIn.signInSilently();
           final gAuth = await gUser?.authentication;
           _accessToken = gAuth?.accessToken;
         } catch (e) {
           debugPrint('Auth: silent sign-in failed: $e');
         }
       }
       notifyListeners();
     });

     _user = _auth.currentUser;
     _isInitializing = false;
     notifyListeners();
   }
   ```

4. **Verify Drive API is Enabled**:
   Ensure the **Google Drive API** is enabled in the Google Cloud Console API Library for project `budgetai-7145b`.
