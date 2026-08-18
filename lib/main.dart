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
import 'utils/app_colors.dart';

/// Tulis error ke file di disk agar bisa dibaca walau device tidak nyambung ADB.
Future<void> _writeCrashLog(String tag, Object error, [StackTrace? stack]) async {
  try {
    final dir = Directory('/sdcard/Download');
    if (!await dir.exists()) return;
    final file = File('/sdcard/Download/hyperbudget_crash.log');
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
      backgroundColor: Colors.red.shade50,
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
                  color: Colors.red,
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
      BudgetAIApp(
        budgetRepository: budgetRepository,
      ),
    );
  } catch (e, stack) {
    // Error di init → layar merah + log file.
    await _writeCrashLog('init', e, stack);
    runApp(_buildErrorScreen('Init gagal: $e', stack));
  }
}

class BudgetAIApp extends StatelessWidget {
  final BudgetRepository budgetRepository;

  const BudgetAIApp({
    super.key,
    required this.budgetRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: budgetRepository),
      ],
      child: MaterialApp(
        title: 'BudgetAI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme(
            brightness: Brightness.light,
            primary: const Color(0xFF58CC02),
            onPrimary: Colors.white,
            secondary: const Color(0xFF1CB0F6),
            onSecondary: Colors.white,
            tertiary: const Color(0xFFFFC800),
            onTertiary: const Color(0xFF100F3E),
            error: const Color(0xFFFF4B4B),
            onError: Colors.white,
            surface: const Color(0xFFFEFEFE),
            onSurface: const Color(0xFF100F3E),
            surfaceContainerLowest: const Color(0xFFF5F5F5),
            surfaceContainerLow: const Color(0xFFFAFAFA),
            surfaceContainer: const Color(0xFFFEFEFE),
            surfaceContainerHigh: Colors.white,
            outline: const Color(0xFFE5E5E5),
            outlineVariant: const Color(0xFFF0F0F0),
            shadow: Colors.black,
          ),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
          textTheme: GoogleFonts.nunitoTextTheme().copyWith(
            displayLarge: GoogleFonts.nunito(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1.1,
              color: const Color(0xFF58CC02),
            ),
            displayMedium: GoogleFonts.nunito(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.15,
              color: const Color(0xFF100F3E),
            ),
            displaySmall: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.2,
              color: const Color(0xFF100F3E),
            ),
            headlineLarge: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.25,
              color: const Color(0xFF100F3E),
            ),
            headlineMedium: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.3,
              color: const Color(0xFF100F3E),
            ),
            headlineSmall: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.3,
              color: const Color(0xFF100F3E),
            ),
            titleLarge: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.4,
              color: const Color(0xFF100F3E),
            ),
            titleMedium: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.4,
              color: const Color(0xFF100F3E),
            ),
            titleSmall: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1.4,
              color: const Color(0xFF4B4B4B),
            ),
            bodyLarge: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.5,
              color: const Color(0xFF4B4B4B),
            ),
            bodyMedium: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.5,
              color: const Color(0xFF777777),
            ),
            bodySmall: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.5,
              color: const Color(0xFF777777),
            ),
            labelLarge: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.4,
              color: const Color(0xFF100F3E),
            ),
            labelMedium: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.4,
              color: const Color(0xFF4B4B4B),
            ),
            labelSmall: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              height: 1.4,
              color: const Color(0xFFAFAFAF),
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: const Color(0xFF58CC02),
            foregroundColor: Colors.white,
            titleTextStyle: GoogleFonts.nunito(
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
              borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF4B4B), width: 2),
            ),
            hintStyle: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF777777),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF58CC02),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF58CC02),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          dividerTheme: const DividerThemeData(
            color: Color(0xFFE5E5E5),
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
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    HistoryScreen(),
    SummaryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE5E5E5), width: 2),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFD7F5B2),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
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
