import 'package:flutter/material.dart';
import 'chat_inbox_screen.dart';
import 'services/app_preferences.dart';
import 'services/nobox_api_service.dart';

/// Halaman Sign In NoBox Chat dengan estetika modern, minimalis, dan presisi
/// (Linear / Apple / Vercel grade) sesuai Anti AI Slop Protocol.
class LoginScreen extends StatefulWidget {
  final Widget? destination;
  final bool initialDarkMode;
  final VoidCallback? onLoginSuccess;

  const LoginScreen({
    super.key,
    this.destination,
    this.initialDarkMode = true,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _bgDark = Color(0xFF090D16);
  static const Color _cardBg = Color(0xFF111726);
  static const Color _inputBg = Color(0xFF0B101D);
  static const Color _brandPrimary = Color(0xFF0066FF);
  static const Color _textMuted = Color(0xFF94A3B8);

  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _isPasswordVisible = false;
  bool _rememberEmail = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final String? savedUsername = await AppPreferences.getString('remembered_email') ??
        await AppPreferences.getString('last_username');
    final bool? savedRemember = await AppPreferences.getBool('remember_email');

    if (mounted) {
      setState(() {
        if (savedRemember != null) {
          _rememberEmail = savedRemember;
        }
        if (savedUsername != null && savedUsername.isNotEmpty) {
          _usernameController.text = savedUsername;
        }
      });
    }
  }

  Future<void> _handleSignIn() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Masukkan email atau username Anda.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Masukkan kata sandi Anda.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Eksekusi login ke backend nobox.ai terlebih dahulu
      final bool success =
          await NoboxApiService().login(username, password);

      if (!mounted) return;

      if (success) {
        // 2. Simpan preferensi secara asinkron tanpa memblokir alur navigasi
        if (_rememberEmail) {
          await AppPreferences.setString('remembered_email', username);
          await AppPreferences.setBool('remember_email', true);
        } else {
          await AppPreferences.remove('remembered_email');
          await AppPreferences.setBool('remember_email', false);
        }

        _navigateToDestination();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = NoboxApiService().lastError ??
              'Gagal masuk. Periksa kembali email dan kata sandi Anda.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal terhubung ke nobox.ai: $e';
      });
    }
  }

  void _navigateToDestination() {
    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
      return;
    }
    final Widget target = widget.destination ?? const ChatInboxScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: target,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.white.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // Subtle ambient glow at top center
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _brandPrimary.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo Icon
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo_transparent.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, error, stackTrace) =>
                                const Icon(
                              Icons.view_in_ar_rounded,
                              size: 32,
                              color: _brandPrimary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Brand Name
                      const Text(
                        'Nobox Chat',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Subtitle
                      const Text(
                        'Masuk ke akun Anda untuk melanjutkan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: _textMuted,
                          letterSpacing: 0.1,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Auth Form Card
                      Container(
                        padding: const EdgeInsets.all(22.0),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: borderColor,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Error Banner
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      color: Color(0xFFEF4444),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Username / Email
                            const Text(
                              'Email atau Username',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                color: _textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _usernameController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: _inputBg,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                hintText: 'nama@perusahaan.com',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: borderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: _brandPrimary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Password
                            const Text(
                              'Kata Sandi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                color: _textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleSignIn(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: _inputBg,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 18,
                                    color: const Color(0xFF64748B),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                hintText: '••••••••',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: borderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: _brandPrimary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Remember Me
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _rememberEmail = !_rememberEmail;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: _rememberEmail
                                            ? _brandPrimary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _rememberEmail
                                              ? _brandPrimary
                                              : const Color(0xFF475569),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: _rememberEmail
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 12,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Ingat saya',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w400,
                                        color: _textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Submit Button
                            SizedBox(
                              height: 44,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _handleSignIn,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _brandPrimary,
                                  disabledBackgroundColor:
                                      _brandPrimary.withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Masuk',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
