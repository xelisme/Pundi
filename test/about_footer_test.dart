import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:hyper_budget_flutter/screens/settings_screen.dart';
import 'package:hyper_budget_flutter/utils/app_info.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BudgetRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = BudgetRepository();
    await repo.init();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The footer sits at the very bottom of a long scroll view, and slivers
  // build lazily — scroll to it rather than assuming it is laid out.
  Future<void> scrollToFooter(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Lihat lisensi'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the footer shows the version and copyright notice',
      (WidgetTester tester) async {
    await pumpSettings(tester);
    await scrollToFooter(tester);

    expect(find.text('$appName v$appVersion'), findsOneWidget);
    expect(
      find.textContaining('© $appCopyrightYear $appCopyrightHolder'),
      findsOneWidget,
    );
    expect(find.textContaining('Lisensi $appLicenseName'), findsOneWidget);
  });

  testWidgets('tapping the license link opens the real grant, selectable',
      (WidgetTester tester) async {
    await pumpSettings(tester);
    await scrollToFooter(tester);

    await tester.tap(find.text('Lihat lisensi'));
    await tester.pumpAndSettle();

    expect(find.text('Lisensi $appLicenseName'), findsOneWidget);
    // The actual MIT permission wording, not a summary.
    expect(
      find.textContaining('Permission is hereby granted, free of charge'),
      findsOneWidget,
    );
    expect(
      find.textContaining('WITHOUT WARRANTY OF ANY KIND'),
      findsOneWidget,
    );

    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Lihat lisensi'), findsOneWidget);
  });

  testWidgets('the in-app license text matches the LICENSE file',
      (WidgetTester tester) async {
    // Same terms in the app and in the repo: the notice is only meaningful if
    // the two copies agree.
    //
    // runAsync is required — flutter_test drives test bodies on a fake clock,
    // and real file IO never completes inside that zone.
    final file = await tester.runAsync(() => File('LICENSE').readAsString());
    expect(_normalize(appLicenseText), _normalize(file!));
  });

  test('the notice names the license and the holder', () {
    expect(appCopyrightNotice,
        '© $appCopyrightYear $appCopyrightHolder · Lisensi $appLicenseName');
  });
}

/// Compare ignoring line-ending style and trailing whitespace, so a CRLF
/// checkout on Windows does not read as a license change.
String _normalize(String value) => value
    .replaceAll('\r\n', '\n')
    .split('\n')
    .map((line) => line.trimRight())
    .join('\n')
    .trim();