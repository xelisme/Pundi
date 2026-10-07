import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'repositories/budget_repository.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/settings_screen.dart';
import 'state/ledger_filter_controller.dart';
import 'state/main_tab_controller.dart';
import 'utils/app_colors.dart';

/// Tulis error ke file di disk agar bisa dibaca walau device tidak nyambung ADB.
Future<void> _writeCrashLog(String tag, Object error, [StackTrace? stack]) async {
  try {
    final dir = Directory('/sdcard/Download');
    if (!await dir.exists()) return;
    final file = File('/sdcard/Download/pundi_crash.log');
    final ts = DateTime.now().toIso8601String();
    final content =
        '[$ts] $tag\n$error\n\n${stack ?? ""}\n${'-' * 60}\n';
    await file.writeAsString(content, mode: FileMode.append);
  } catch (_) {
    // abaikan kalau gagal menulis
  }
}

/// Layar merah pengganti layar hitam: menampilkan pesan error secara utuh.
Widget _buildErrorScreen(Object error, [StackTrace? stack]) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: AppColors.error.withValues(alpha: 0.05),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terjadi error (bukan layar hitam)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$error\n\n${stack ?? ""}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() async {
  // Tangkap error saat build widget → tampilkan layar merah (bukan hitam).
  ErrorWidget.builder = (FlutterErrorDetails details) {
    _writeCrashLog('build', details.exception, details.stack);
    return _buildErrorScreen(details.exception, details.stack);
  };

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDateFormatting('id_ID', null);

    // Inisialisasi repository lokal (SharedPreferences).
    final budgetRepository = BudgetRepository();
    await budgetRepository.init();

    runApp(
      PundiApp(
        budgetRepository: budgetRepository,
      ),
    );
  } catch (e, stack) {
    // Error di init → layar merah + log file.
    await _writeCrashLog('init', e, stack);
    runApp(_buildErrorScreen('Init gagal: $e', stack));
  }
}

class PundiApp extends StatelessWidget {
  final BudgetRepository budgetRepository;

  const PundiApp({
    super.key,
    required this.budgetRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: budgetRepository),
        // Above the tab shell on purpose: Ringkasan states a filtered total and
        // Riwayat has to list exactly the records behind it, so the selection
        // must outlive whichever screen is on top.
        ChangeNotifierProvider(create: (_) => LedgerFilterController()),
        ChangeNotifierProvider(create: (_) => MainTabController()),
      ],
      child: MaterialApp(
        title: 'Pundi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme(
            brightness: Brightness.light,
            primary: AppColors.green,
            onPrimary: Colors.white,
            secondary: AppColors.blue,
            onSecondary: Colors.white,
            tertiary: AppColors.success,
            onTertiary: AppColors.textPrimary,
            error: AppColors.error,
            onError: Colors.white,
            surface: AppColors.surfaceWhite,
            onSurface: AppColors.textPrimary,
            surfaceContainerLowest: const Color(0xFFF5F5F5),
            surfaceContainerLow: const Color(0xFFFAFAFA),
            surfaceContainer: AppColors.surfaceWhite,
            surfaceContainerHigh: AppColors.surfaceWhite,
            outline: AppColors.border,
            outlineVariant: AppColors.divider,
            shadow: Colors.black,
          ),
          scaffoldBackgroundColor: AppColors.background,
          useMaterial3: true,
          textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
            displayLarge: GoogleFonts.plusJakartaSans(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1.1,
              color: AppColors.green,
            ),
            displayMedium: GoogleFonts.plusJakartaSans(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.15,
              color: AppColors.textPrimary,
            ),
            displaySmall: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.2,
              color: AppColors.textPrimary,
            ),
            headlineLarge: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
            headlineMedium: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.3,
              color: AppColors.textPrimary,
            ),
            headlineSmall: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.3,
              color: AppColors.textPrimary,
            ),
            titleLarge: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
            titleMedium: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
            titleSmall: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
            bodyLarge: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
            bodyMedium: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.5,
              color: AppColors.textTertiary,
            ),
            bodySmall: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.5,
              color: AppColors.textTertiary,
            ),
            labelLarge: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
            labelMedium: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
            labelSmall: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              height: 1.4,
              color: AppColors.textTertiary,
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 2,
            shadowColor: AppColors.cardShadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            titleTextStyle: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.green, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textTertiary,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          dividerTheme: const DividerThemeData(
            color: AppColors.border,
            thickness: 1,
            space: 1,
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('id', 'ID'),
          Locale('en', 'US'),
        ],
        locale: const Locale('id', 'ID'),
        home: const MainNavigation(),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final _screens = const [
    HomeScreen(),
    HistoryScreen(),
    SummaryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Read from the controller rather than holding the index in State, so
    // Ringkasan can send the user to Riwayat when they tap a category to see
    // the records behind a total.
    final tabs = context.watch<MainTabController>();

    return Scaffold(
      body: IndexedStack(
        index: tabs.index,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 2),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFD7F5B2),
          selectedIndex: tabs.index,
          onDestinationSelected: tabs.select,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.green),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history, color: AppColors.green),
              label: 'Riwayat',
            ),
            NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart, color: AppColors.green),
              label: 'Ringkasan',
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings, color: AppColors.green),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }
}
