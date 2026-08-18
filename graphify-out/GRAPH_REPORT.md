# Graph Report - hyper_budget_flutter  (2026-08-18)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 596 nodes · 783 edges · 30 communities (26 shown, 4 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 18 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `ab22fe95`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Win32Window
- app_colors.dart
- GeneratedPluginRegistrant.swift
- main.dart
- budget_repository.dart
- edit_category_dialog.dart
- drive_service.dart
- summary_screen.dart
- auth_service.dart
- home_screen.dart
- my_application.cc
- transaction.dart
- radial_allocation_viz.dart
- settings_screen.dart
- duolingo_card.dart
- duolingo_button.dart
- State
- wWinMain
- history_screen.dart
- manifest.json
- StatelessWidget
- firebase_options.dart
- MainActivity.kt
- widget_test.dart
- _AuthHttpClient
- String?

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 22 edges
2. `BudgetRepository` - 20 edges
3. `MessageHandler` - 12 edges
4. `FlutterWindow` - 10 edges
5. `Create` - 10 edges
6. `WndProc` - 10 edges
7. `MessageHandler` - 9 edges
8. `AuthService` - 8 edges
9. `WindowClassRegistrar` - 7 edges
10. `_MyApplication` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `_confirmDelete` --references--> `BudgetRepository`  [EXTRACTED]
  lib/screens/history_screen.dart → lib/repositories/budget_repository.dart
- `_showEditDialog` --references--> `BudgetRepository`  [EXTRACTED]
  lib/screens/history_screen.dart → lib/repositories/budget_repository.dart
- `OnCreate` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.h → windows/flutter/generated_plugin_registrant.cc

## Import Cycles
- None detected.

## Communities (30 total, 4 thin omitted)

### Community 0 - "Win32Window"
Cohesion: 0.06
Nodes (53): PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject, HWND (+45 more)

### Community 1 - "app_colors.dart"
Cohesion: 0.04
Nodes (47): accent, accentTint, AppColors, background, baseBeige, baseBrown, blue, blueTint (+39 more)

### Community 2 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.05
Nodes (32): Any, Cocoa, file_picker, firebase_auth, firebase_core, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge (+24 more)

### Community 3 - "main.dart"
Cohesion: 0.07
Nodes (37): ChangeNotifier, dart:io, firebase_options.dart, authService, budgetRepository, build, _buildErrorScreen, createState (+29 more)

### Community 4 - "budget_repository.dart"
Cohesion: 0.06
Nodes (34): addCategory, _categories, clearHistory, deleteCategory, deleteTransaction, _driveService, _escapeCsv, exportAllData (+26 more)

### Community 5 - "edit_category_dialog.dart"
Cohesion: 0.06
Nodes (32): double get, _extractAmount, IncomeParser, IncomeParserResult, parse, splits, totalAmount, build (+24 more)

### Community 6 - "drive_service.dart"
Cohesion: 0.06
Nodes (30): auth_service.dart, dart:convert, DateTime? get, DriveApi?, _authService, downloadData, _driveApi, _ensureDriveApi (+22 more)

### Community 7 - "summary_screen.dart"
Cohesion: 0.07
Nodes (29): int get, balance, balances, build, _buildHeroMetric, _buildSupportingMetric, _calculateMonthlySummary, _CategoryBalance (+21 more)

### Community 8 - "auth_service.dart"
Cohesion: 0.07
Nodes (28): bool get, Client, dart:async, FirebaseAuth, GoogleSignIn, _accessToken, _auth, authStateChanges (+20 more)

### Community 9 - "home_screen.dart"
Cohesion: 0.07
Nodes (27): DateTime, build, _buildExpenseSection, _buildIncomeSection, _buildMiniMetric, _buildModeToggle, color, createState (+19 more)

### Community 10 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 11 - "transaction.dart"
Cohesion: 0.08
Nodes (25): allCategoriesLabel, allocatedAmount, category, CategorySplitResult, chargedTo, colorHex, description, fromJson (+17 more)

### Community 12 - "radial_allocation_viz.dart"
Cohesion: 0.08
Nodes (23): Animation, AnimationController, CustomPainter, dart:math, double?, allocations, _animation, animationValue (+15 more)

### Community 13 - "settings_screen.dart"
Cohesion: 0.11
Nodes (22): AllocationCategory, BudgetRepository, _submitExpense, _submitIncome, build, color, _confirmDeleteCategory, _confirmReset (+14 more)

### Community 14 - "duolingo_card.dart"
Cohesion: 0.09
Nodes (21): EdgeInsetsGeometry?, borderColor, borderWidth, build, child, color, createState, hoverable (+13 more)

### Community 15 - "duolingo_button.dart"
Cohesion: 0.13
Nodes (15): Color, IconData, build, createState, DuolingoButton, _DuolingoButtonState, DuolingoButtonType, fullWidth (+7 more)

### Community 16 - "State"
Cohesion: 0.21
Nodes (13): MainNavigation, _MainNavigationState, SummaryScreen, _SummaryScreenState, DuolingoCard, _DuolingoCardState, EditCategoryDialog, _EditCategoryDialogState (+5 more)

### Community 17 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 18 - "history_screen.dart"
Cohesion: 0.18
Nodes (11): build, _confirmDelete, createState, _fmt, HistoryScreen, _HistoryScreenState, _showEditDialog, _showTransactionOptions (+3 more)

### Community 19 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 20 - "StatelessWidget"
Cohesion: 0.25
Nodes (8): BudgetAIApp, AuthWrapper, _CategoryChip, _SettingsAction, SettingsScreen, DuolingoListCard, DuolingoMetricCard, StatelessWidget

### Community 21 - "firebase_options.dart"
Cohesion: 0.33
Nodes (5): android, DefaultFirebaseOptions, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

## Knowledge Gaps
- **321 isolated node(s):** `flutter_controller_`, `project_`, `child_content_`, `quit_on_close_`, `window_handle_` (+316 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AuthService` connect `main.dart` to `auth_service.dart`, `drive_service.dart`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Why does `BudgetRepository` connect `settings_screen.dart` to `main.dart`, `budget_repository.dart`, `summary_screen.dart`, `home_screen.dart`, `history_screen.dart`, `StatelessWidget`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Why does `FlutterWindow` connect `Win32Window` to `GeneratedPluginRegistrant.swift`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `MessageHandler` (e.g. with `Destroy` and `GetClientArea`) actually correct?**
  _`MessageHandler` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `flutter_controller_`, `project_`, `child_content_` to the rest of the system?**
  _321 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.0597567424643046 - nodes in this community are weakly interconnected._
- **Should `app_colors.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.041666666666666664 - nodes in this community are weakly interconnected._