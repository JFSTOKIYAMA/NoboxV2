import 'package:flutter/material.dart';
import 'chat_inbox_screen.dart';
import 'login_screen.dart';
import 'services/nobox_api_service.dart';

/// LoadingScreen bergaya modern, minimalis, dan berkelas tinggi (Anti AI Slop).
/// Menampilkan logo Nobox dengan efek floating, ambient glow, status dinamis,
/// dan progress bar presisi.
class LoadingScreen extends StatefulWidget {
  final Widget? destination;
  final VoidCallback? onComplete;
  final Duration duration;

  const LoadingScreen({
    super.key,
    this.destination,
    this.onComplete,
    this.duration = const Duration(milliseconds: 3200),
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final AnimationController _progressController;
  late final AnimationController _dotController;

  late final Animation<double> _floatAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _fadeAnimation;

  final List<String> _statusMessages = [
    'Menyiapkan sistem...',
    'Memvalidasi konfigurasi...',
    'Menghubungkan layanan...',
    'Sinkronisasi modul...',
    'Hampir selesai...',
  ];

  int _currentStatusIndex = 0;

  @override
  void initState() {
    super.initState();

    // 1. Controller untuk efek melayang (floating motion)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    // 2. Controller untuk ambient glow halus
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // 3. Controller untuk animasi 3 titik "Loading..."
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // 4. Controller untuk progress loading bar
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _progressController,
      curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
    );

    _progressController.addListener(() {
      final double progress = _progressController.value;
      final int newIndex = (progress * _statusMessages.length)
          .clamp(0, _statusMessages.length - 1)
          .toInt();
      if (newIndex != _currentStatusIndex) {
        setState(() {
          _currentStatusIndex = newIndex;
        });
      }
    });

    // Sinkronkan sesi akun di background saat animasi berjalan
    NoboxApiService().init();

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          if (widget.onComplete != null) {
            widget.onComplete!();
          } else if (widget.destination != null) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 600),
                pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
                  opacity: animation,
                  child: widget.destination!,
                ),
              ),
            );
          } else {
            final bool isLoggedIn = NoboxApiService().isLoggedIn;
            final Widget target = isLoggedIn
                ? const ChatInboxScreen()
                : const LoginScreen(destination: ChatInboxScreen());
            Navigator.of(context).pushReplacement(
              PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 600),
                pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
                  opacity: animation,
                  child: target,
                ),
              ),
            );
          }
        });
      }
    });

    // Mulai progress dengan penundaan mikro
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _progressController.forward();
      }
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandPrimary = Color(0xFF0066FF);
    const Color brandAccent = Color(0xFF38BDF8);
    const Color bgDark = Color(0xFF090D16);
    const Color cardBg = Color(0x1AFFFFFF);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Background ambient gradient aura
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) {
                final double auraScale = _pulseAnimation.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 0.9 * auraScale,
                      colors: [
                        brandPrimary.withValues(alpha: 0.18 * auraScale),
                        brandPrimary.withValues(alpha: 0.05 * auraScale),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Halus grid background motif
          Positioned.fill(
            child: CustomPaint(
              painter: _TechBackgroundPainter(),
            ),
          ),

          // Konten Utama
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _floatController,
                    _pulseController,
                    _progressController,
                    _dotController,
                  ]),
                  builder: (context, _) {
                    final double progress = _progressController.value;
                    final int percent = (progress * 100).toInt();

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),

                        // Bagian Logo dengan Floating & Ambient Glow
                        Transform.translate(
                          offset: Offset(0, _floatAnimation.value),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Radial outer ring pulse
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: brandPrimary.withValues(
                                        alpha: 0.28 * _pulseAnimation.value,
                                      ),
                                      blurRadius: 45,
                                      spreadRadius: 10 * _pulseAnimation.value,
                                    ),
                                  ],
                                ),
                              ),

                              // Glassmorphic Logo Card
                              Container(
                                width: 140,
                                height: 140,
                                padding: const EdgeInsets.all(22.0),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'assets/images/logo_transparent.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, error, stackTrace) {
                                      return Image.asset(
                                        'assets/images/logo.jpg',
                                        fit: BoxFit.contain,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Title Brand "NOBOX"
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'NO',
                                style: TextStyle(
                                  fontFamily: 'sans-serif',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4.5,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                              const Text(
                                'BOX',
                                style: TextStyle(
                                  fontFamily: 'sans-serif',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4.5,
                                  color: brandAccent,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Wadah Loading Bar & Dynamic Text
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Baris: "Loading..." dan Persentase "XX%"
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  // Loading text with synchronized animated dot progression
                                  _buildAnimatedLoadingText(brandAccent),

                                  // Tabular Percentage
                                  Text(
                                    '$percent%',
                                    style: TextStyle(
                                      fontFamily: 'sans-serif',
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Sleek Minimalist Progress Bar
                              Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Stack(
                                  children: [
                                    // Progress fill with glow & gradient
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress.clamp(0.01, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          gradient: const LinearGradient(
                                            colors: [
                                              brandPrimary,
                                              brandAccent,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: brandPrimary.withValues(
                                                alpha: 0.6,
                                              ),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Dynamic Status Text (Smooth Switch)
                              Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.0, 0.25),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    _statusMessages[_currentStatusIndex],
                                    key: ValueKey<int>(_currentStatusIndex),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.3,
                                      color: Colors.white.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),


        ],
      ),
    );
  }

  /// Menghasilkan teks "Loading" yang diikuti 3 titik berirama dinamis
  Widget _buildAnimatedLoadingText(Color dotColor) {
    // 0..1 interval dibagi 3 tahap
    final double val = _dotController.value * 3.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Loading',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final double dotProgress = (val - index).clamp(0.0, 1.0);
            final double opacity = dotProgress > 0.3 ? 0.95 : 0.25;
            final double scale = 0.7 + (dotProgress * 0.4);

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 3.5,
                height: 3.5,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor.withValues(alpha: opacity),
                  boxShadow: [
                    if (dotProgress > 0.3)
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Custom painter untuk menciptakan sentuhan latar belakang geometris yang sangat subtle
class _TechBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double step = 40.0;
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
