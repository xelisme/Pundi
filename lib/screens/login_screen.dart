import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../widgets/duolingo_button.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    final user = await auth.signIn();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user == null && auth.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError!),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Duolingo hero: green-to-white gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF58CC02), Colors.white],
            stops: [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Duolingo-style hero headline
                  Text(
                    'budgetai',
                    style: GoogleFonts.nunito(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kelola keuangan dengan cerdas',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Sign-in card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          offset: const Offset(0, 4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.savings_outlined,
                            size: 32,
                            color: AppColors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'MULAI SEKARANG',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: AppColors.grayNav,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Masuk untuk menyimpan dan sinkronisasi data anggaran Anda.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.grayLight,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Primary: Google Sign-In (Duolingo 3D button)
                        DuolingoButton(
                          label: 'Masuk dengan Google',
                          onPressed: _signIn,
                          type: DuolingoButtonType.primary,
                          fullWidth: true,
                          isLoading: _isLoading,
                          icon: Icons.login_rounded,
                        ),
                        const SizedBox(height: 16),

                        // Secondary: Skip (Duolingo secondary style)
                        DuolingoButton(
                          label: 'Lewati, pakai offline',
                          onPressed: _skip,
                          type: DuolingoButtonType.secondary,
                          fullWidth: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text(
                    'Data tersimpan aman di Google Drive Anda',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.grayLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
