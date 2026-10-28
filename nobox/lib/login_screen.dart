import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_inbox_screen.dart';
import 'services/nobox_api_service.dart';

/// Halaman Sign In NoBox Chat bergaya Linear / Apple / Vercel (Anti AI Slop).
/// Menghubungkan langsung ke backend nobox.ai dengan palet obsidian, ambient aura,
/// validasi kredensial presisi, dan opsi Remember Email.
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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const Color _brandPrimary = Color(0xFF0066FF);
  static const Color _brandAccent = Color(0xFF38BDF8);

  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _isPasswordVisible = false;
  bool _rememberEmail = true;
  bool _isLoading = false;
  String? _errorMessage;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
    _usernameController = TextEditingController(text: 'dfawwas23@gmail.com');
    _passwordController = TextEditingController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedUsername = prefs.getString('remembered_email') ??
          prefs.getString('last_username');
      final bool? savedRemember = prefs.getBool('remember_email');

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
    } catch (e) {
      debugPrint('LoginScreen: Error loading saved credentials: $e');
    }
  }

  Future<void> _handleSignIn() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Harap masukkan email atau username.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Harap masukkan kata sandi akun Anda.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberEmail) {
        await prefs.setString('remembered_email', username);
        await prefs.setBool('remember_email', true);
      } else {
        await prefs.remove('remembered_email');
        await prefs.setBool('remember_email', false);
      }

      final bool success =
          await NoboxApiService().login(username, password);

      if (!mounted) return;

      if (success) {
        _navigateToDestination();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = NoboxApiService().lastError ??
              'Gagal masuk ke nobox.ai. Periksa kembali email dan kata sandi Anda.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Kendala jaringan backend: $e';
      });
    }
  }

  void _fillDemoAccount() {
    setState(() {
      _usernameController.text = 'dfawwas23@gmail.com';
      _passwordController.text = 'nobox123';
      _errorMessage = null;
    });
  }

  void _enterDemoMode() async {
    final String user = _usernameController.text.trim().isNotEmpty
        ? _usernameController.text.trim()
        : 'dfawwas23@gmail.com';
    await NoboxApiService().setSessionToken(
      'demo-${DateTime.now().millisecondsSinceEpoch}',
      username: user,
    );
    if (!mounted) return;
    _navigateToDestination();
  }

  void _navigateToDestination() {
    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
      return;
    }
    final Widget target = widget.destination ?? const ChatInboxScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor =
        _isDarkMode ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final Color cardBg =
        _isDarkMode ? const Color(0xFF111726) : Colors.white;
    final Color textColor =
        _isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final Color textMuted =
        _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color inputBg =
        _isDarkMode ? const Color(0xFF0D1322) : const Color(0xFFF1F5F9);
    final Color borderColor = _isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Ambient Background Aura
          if (_isDarkMode)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) {
                  final double auraScale = _pulseAnimation.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.45),
                        radius: 0.85 * auraScale,
                        colors: [
                          _brandPrimary.withValues(alpha: 0.16 * auraScale),
                          _brandPrimary.withValues(alpha: 0.04 * auraScale),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),

          // 2. Subtle Tech Grid Pattern
          if (_isDarkMode)
            Positioned.fill(
              child: CustomPaint(
                painter: _LoginGridPainter(),
              ),
            ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                // Top Action Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Subdued Back Indicator if can pop
                      if (Navigator.of(context).canPop())
                        IconButton(
                          tooltip: 'Kembali',
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: textMuted,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      else
                        const SizedBox(width: 40),

                      // Theme Switcher
                      IconButton(
                        tooltip: _isDarkMode ? 'Mode Terang' : 'Mode Gelap',
                        icon: Icon(
                          _isDarkMode
                              ? Icons.light_mode_rounded
                              : Icons.nightlight_round,
                          color: _isDarkMode
                              ? _brandAccent
                              : const Color(0xFF475569),
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _isDarkMode = !_isDarkMode;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Scrollable Form Area
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo Badge
                            Center(
                              child: Container(
                                width: 84,
                                height: 84,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: _isDarkMode
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : const Color(0xFFCBD5E1),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: _isDarkMode ? 0.35 : 0.08,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/logo_transparent.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, error, stackTrace) =>
                                      const Icon(
                                    Icons.view_in_ar_rounded,
                                    size: 44,
                                    color: _brandAccent,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Brand Typography
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'NO',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.8,
                                    color: textColor,
                                  ),
                                ),
                                const Text(
                                  'BOX',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.8,
                                    color: _brandAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _brandPrimary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _brandPrimary.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: const Text(
                                    'CHAT',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: _brandAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'Masuk ke workspace komunikasi pelanggan Anda',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: textMuted,
                                letterSpacing: 0.1,
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Form Card
                            Container(
                              padding: const EdgeInsets.all(24.0),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: borderColor,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: _isDarkMode ? 0.35 : 0.06,
                                    ),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10),
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
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFEF4444)
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
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
                                    const SizedBox(height: 18),
                                  ],

                                  // Username / Email Input
                                  Text(
                                    'Email / Username',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      color: textColor.withValues(alpha: 0.85),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  TextField(
                                    controller: _usernameController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: inputBg,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.alternate_email_rounded,
                                        size: 18,
                                        color: _brandAccent,
                                      ),
                                      hintText: 'nama@domain.com',
                                      hintStyle: TextStyle(
                                        color: textMuted.withValues(alpha: 0.6),
                                        fontSize: 13.5,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: borderColor,
                                          width: 1.1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: _brandPrimary,
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // Password Input
                                  Text(
                                    'Kata Sandi',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      color: textColor.withValues(alpha: 0.85),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _handleSignIn(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: inputBg,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 18,
                                        color: _brandAccent,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _isPasswordVisible
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                          size: 18,
                                          color: textMuted,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isPasswordVisible =
                                                !_isPasswordVisible;
                                          });
                                        },
                                      ),
                                      hintText: 'Masukkan kata sandi',
                                      hintStyle: TextStyle(
                                        color: textMuted.withValues(alpha: 0.6),
                                        fontSize: 13.5,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: borderColor,
                                          width: 1.1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: _brandPrimary,
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // Remember Me & Demo Fill
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
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
                                                width: 17,
                                                height: 17,
                                                decoration: BoxDecoration(
                                                  color: _rememberEmail
                                                      ? _brandPrimary
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: _rememberEmail
                                                        ? _brandPrimary
                                                        : borderColor,
                                                    width: 1.3,
                                                  ),
                                                ),
                                                child: _rememberEmail
                                                    ? const Icon(
                                                        Icons.check_rounded,
                                                        size: 13,
                                                        color: Colors.white,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Ingat sesi saya',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _fillDemoAccount,
                                        icon: const Icon(
                                          Icons.flash_on_rounded,
                                          size: 13,
                                          color: _brandAccent,
                                        ),
                                        label: const Text(
                                          'Isi Demo',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _brandAccent,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // Sign In Button
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: const LinearGradient(
                                        colors: [
                                          _brandPrimary,
                                          Color(0xFF0052CC),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _brandPrimary.withValues(
                                            alpha: _isLoading ? 0.15 : 0.35,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap:
                                            _isLoading ? null : _handleSignIn,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 13,
                                          ),
                                          child: Center(
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Masuk ke NoBox Chat',
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 0.3,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: TextButton(
                                      onPressed: _enterDemoMode,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Atau masuk via Mode Demo (Offline)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textMuted.withValues(alpha: 0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Security & Trust Indicator
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 13,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Terenkripsi SSL • Terhubung ke backend nobox.ai',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                    color: textMuted.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter background kisi geometris minimalis
class _LoginGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double step = 42.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
