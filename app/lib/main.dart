import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // generated from google-services.json by the build
import 'models.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/db.dart';
import 'services/device.dart';
import 'services/food_db.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!DefaultFirebaseOptions.configured) {
    runApp(const _SetupMissingApp());
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FoodDb.instance.all(); // warm up the food list
  Reminders.instance.init().then((_) => Reminders.instance.apply()).catchError((_) {});
  runApp(const CalorieApp());
}

class CalorieApp extends StatelessWidget {
  const CalorieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Calorie Counter',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // phones with very large font settings: grow text a little, but keep layouts intact
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.12)),
          child: child!,
        );
      },
      home: const SplashGate(),
    );
  }
}

/// Animated logo for a moment, then the real app.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _done ? const AuthGate() : _Splash(controller: _c),
    );
  }
}

class _Splash extends StatelessWidget {
  final AnimationController controller;
  const _Splash({required this.controller});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final t = controller.value;
            double seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
            return Column(mainAxisSize: MainAxisSize.min, children: [
              CustomPaint(
                size: const Size(132, 132),
                painter: SplashLogoPainter(
                  rim: Curves.easeOutCubic.transform(seg(0.05, 0.7)) * 0.75,
                  dots: [seg(0.35, 0.6), seg(0.45, 0.7), seg(0.55, 0.8)]
                      .map((x) => Curves.elasticOut.transform(x))
                      .toList(),
                  p: p,
                ),
              ),
              const SizedBox(height: 20),
              Opacity(
                opacity: seg(0.5, 0.85),
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - seg(0.5, 0.85))),
                  child: Text('AI Calorie Counter', style: display(context, 24)),
                ),
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: seg(0.65, 1),
                child: Text("Know what's on your plate",
                    style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class SplashLogoPainter extends CustomPainter {
  final double rim;
  final List<double> dots;
  final Palette p;
  SplashLogoPainter({required this.rim, required this.dots, required this.p});
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero), r = s.width / 2 - 8;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, ring..color = p.plateTrack);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, math.pi * 2 * rim,
        false, ring..color = p.saffron);
    const pos = [Offset(-22, -10), Offset(22, -10), Offset(0, 24)];
    final cols = [p.leaf, p.wheat, p.chili];
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(c + pos[i], 13 * dots[i], Paint()..color = cols[i]);
    }
  }

  @override
  bool shouldRepaint(SplashLogoPainter o) => o.rim != rim || o.dots != dots;
}

/// Signed out -> AuthScreen. Signed in without profile -> Onboarding. Else Home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Loading();
        final user = snap.data;
        if (user == null) return const _GuestStart();
        return StreamBuilder<Profile?>(
          key: ValueKey(user.uid),
          stream: Db.instance.profileStream(),
          builder: (context, p) {
            if (p.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load your account.\n${p.error}',
                        textAlign: TextAlign.center),
                  ),
                ),
              );
            }
            if (!p.hasData && p.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            final profile = p.data;
            if (profile == null) return const OnboardingScreen();
            return HomeShell(profile: profile);
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}


/// Shown only when the app was built before Firebase was connected.
class _SetupMissingApp extends StatelessWidget {
  const _SetupMissingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'AI Calorie Counter\n\nAlmost ready! This test build is not connected to Firebase yet. '
              'Add google-services.json to the project and a new APK will be built.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}


/// No account yet: start straight away as a guest (login is optional, in setup and Profile).
class _GuestStart extends StatefulWidget {
  const _GuestStart();
  @override
  State<_GuestStart> createState() => _GuestStartState();
}

class _GuestStartState extends State<_GuestStart> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    setState(() => _failed = false);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_failed) return const _Loading();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not start. Check your internet connection.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _go, child: const Text('Try again')),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen(popOnDone: true))),
              child: const Text('Log in instead'),
            ),
          ]),
        ),
      ),
    );
  }
}
