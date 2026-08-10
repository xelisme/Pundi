import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'repositories/budget_repository.dart';
import 'services/auth_service.dart';
import 'services/drive_service.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('id_ID', null);
  runApp(const BudgetAIApp());
}

class BudgetAIApp extends StatefulWidget {
  const BudgetAIApp({super.key});

  @override
  State<BudgetAIApp> createState() => _BudgetAIAppState();
}

class _BudgetAIAppState extends State<BudgetAIApp> {
  late final AuthService _authService;
  late final DriveService _driveService;
  late final BudgetRepository _budgetRepository;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _driveService = DriveService(_authService);
    _budgetRepository = BudgetRepository(driveService: _driveService);
    _initAuth();
  }

  Future<void> _initAuth() async {
    await _authService.init();
    await _budgetRepository.init();
    await _driveService.loadLastSyncTime();

    _authService.addListener(() {
      final user = _authService.user;
      if (user != null) {
        _budgetRepository.loadFromCloud();
      }
    });

    if (_authService.isSignedIn) {
      await _budgetRepository.loadFromCloud();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _driveService),
        ChangeNotifierProvider.value(value: _budgetRepository),
      ],
      child: MaterialApp(
        title: 'BudgetAI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // Luxury Minimal Color Scheme
          colorScheme: ColorScheme(
            brightness: Brightness.light,
            primary: const Color(0xFF8B3A3A), // Burgundy accent
            onPrimary: const Color(0xFFFDFBF7),
            secondary: const Color(0xFF8B3A3A),
            onSecondary: const Color(0xFFFDFBF7),
            tertiary: const Color(0xFF6B7F6E), // Income sage
            onTertiary: const Color(0xFFFDFBF7),
            error: const Color(0xFF8B6B5F),
            onError: const Color(0xFFFDFBF7),
            surface: const Color(0xFFFDFBF7), // Card surface
            onSurface: const Color(0xFF2C2420), // Deep brown text
            surfaceContainerLowest: const Color(0xFFE8E4DD), // Base beige
            surfaceContainerLow: const Color(0xFFF5F2EC),
            surfaceContainer: const Color(0xFFFDFBF7),
            surfaceContainerHigh: Colors.white,
            outline: const Color(0xFFD9D3CC),
            outlineVariant: const Color(0xFFEBE7E1),
            shadow: const Color(0xFF504028),
          ),
          scaffoldBackgroundColor: const Color(0xFFE8E4DD),
          useMaterial3: true,
          
          // Luxury Minimal Typography - Lora serif for numbers, Inter for UI
          textTheme: GoogleFonts.interTextTheme().copyWith(
            displayLarge: GoogleFonts.lora(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.02,
              height: 1.1,
              color: const Color(0xFF2C2420),
            ),
            displayMedium: GoogleFonts.lora(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.02,
              height: 1.15,
              color: const Color(0xFF2C2420),
            ),
            displaySmall: GoogleFonts.lora(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.01,
              height: 1.2,
              color: const Color(0xFF2C2420),
            ),
            headlineLarge: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.02,
              height: 1.25,
              color: const Color(0xFF2C2420),
            ),
            headlineMedium: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.01,
              height: 1.3,
              color: const Color(0xFF2C2420),
            ),
            headlineSmall: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.01,
              height: 1.3,
              color: const Color(0xFF2C2420),
            ),
            titleLarge: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.01,
              height: 1.4,
              color: const Color(0xFF2C2420),
            ),
            titleMedium: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.4,
              color: const Color(0xFF2C2420),
            ),
            titleSmall: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.4,
              color: const Color(0xFF5A4E47),
            ),
            bodyLarge: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.5,
              color: const Color(0xFF2C2420),
            ),
            bodyMedium: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.5,
              color: const Color(0xFF5A4E47),
            ),
            bodySmall: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 1.5,
              color: const Color(0xFF8A7F77),
            ),
            labelLarge: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              height: 1.4,
              color: const Color(0xFF2C2420),
            ),
            labelMedium: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              height: 1.4,
              color: const Color(0xFF5A4E47),
            ),
            labelSmall: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.01,
              height: 1.4,
              color: const Color(0xFF8A7F77),
            ),
          ),
          
          // Refined card elevation
          cardTheme: CardThemeData(
            color: const Color(0xFFFDFBF7),
            elevation: 0,
            shadowColor: const Color(0xFF504028).withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          
          // AppBar with new palette
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: const Color(0xFF2C2420),
            foregroundColor: const Color(0xFFFDFBF7),
            titleTextStyle: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFDFBF7),
            ),
          ),
          
          // Input decoration - minimal, refined
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFFDFBF7),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD9D3CC), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD9D3CC), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B3A3A), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B6B5F), width: 1),
            ),
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8A7F77),
            ),
          ),
          
          // Filled button with burgundy accent
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B3A3A),
              foregroundColor: const Color(0xFFFDFBF7),
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          
          // Elevated button
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B3A3A),
              foregroundColor: const Color(0xFFFDFBF7),
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          
          // Divider
          dividerTheme: const DividerThemeData(
            color: Color(0xFFEBE7E1),
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
        home: const AuthWrapper(),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Ringkasan'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Pengaturan'),
        ],
      ),
    );
  }
}
