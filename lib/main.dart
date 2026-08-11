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
import 'utils/app_colors.dart';

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
          // Duolingo Bright Color Scheme
          colorScheme: ColorScheme(
            brightness: Brightness.light,
            primary: const Color(0xFF58CC02), // Duolingo green
            onPrimary: Colors.white,
            secondary: const Color(0xFF1CB0F6), // Duolingo blue
            onSecondary: Colors.white,
            tertiary: const Color(0xFFFFC800), // Duolingo golden
            onTertiary: const Color(0xFF100F3E),
            error: const Color(0xFFFF4B4B), // Duolingo red
            onError: Colors.white,
            surface: const Color(0xFFFEFEFE), // Almost white
            onSurface: const Color(0xFF100F3E), // Dark blue text
            surfaceContainerLowest: const Color(0xFFF5F5F5),
            surfaceContainerLow: const Color(0xFFFAFAFA),
            surfaceContainer: const Color(0xFFFEFEFE),
            surfaceContainerHigh: Colors.white,
            outline: const Color(0xFFE5E5E5), // Border color
            outlineVariant: const Color(0xFFF0F0F0),
            shadow: Colors.black,
          ),
          scaffoldBackgroundColor: Colors.white, // Pure white
          useMaterial3: true,
          
          // Duolingo Playful Typography - Nunito rounded sans
          textTheme: GoogleFonts.nunitoTextTheme().copyWith(
            displayLarge: GoogleFonts.nunito(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1.1,
              color: const Color(0xFF58CC02), // Green for hero
            ),
            displayMedium: GoogleFonts.nunito(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.15,
              color: const Color(0xFF100F3E), // Dark blue
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
              color: const Color(0xFF4B4B4B), // Gray text
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
              color: const Color(0xFF777777), // Light gray
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
              fontWeight: FontWeight.w800, // Duolingo section labels
              letterSpacing: 2, // Duolingo: 2px tracking
              height: 1.4,
              color: const Color(0xFFAFAFAF), // Nav gray
            ),
          ),
          
          // Duolingo 3D card style
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 2, // Subtle elevation for depth
            shadowColor: Colors.black.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Duolingo: 12px
            ),
          ),
          
          // AppBar with Duolingo green
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: const Color(0xFF58CC02), // Green
            foregroundColor: Colors.white,
            titleTextStyle: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          
          // Input decoration - Duolingo style
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), // Duolingo: 12px
              borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2), // Green
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF4B4B), width: 2), // Red
            ),
            hintStyle: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF777777),
            ),
          ),
          
          // Duolingo 3D green button
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF58CC02), // Duolingo green
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Duolingo: 12px
              ),
              textStyle: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700, // Bold
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          // Elevated button - Duolingo 3D style
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF58CC02), // Green
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
          
          // Divider - Duolingo style
          dividerTheme: const DividerThemeData(
            color: Color(0xFFE5E5E5), // Duolingo border color
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE5E5E5), width: 2),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFD7F5B2),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.green),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history, color: AppColors.green),
              label: 'Riwayat',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart, color: AppColors.green),
              label: 'Ringkasan',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings, color: AppColors.green),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }
}
