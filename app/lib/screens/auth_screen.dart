import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart' show SplashLogoPainter;
import '../theme.dart';
import '../widgets/ui.dart';

class AuthScreen extends StatefulWidget {
  /// Opened from inside the app (setup or Profile): shows a back button and closes itself when done.
  final bool popOnDone;
  /// Start on "Create account" and keep the guest's data by linking it to the new email.
  final bool saveGuest;
  const AuthScreen({super.key, this.popOnDone = false, this.saveGuest = false});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  late bool _signUp = widget.saveGuest;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks wrong.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Sign in instead.';
      case 'weak-password':
        return 'Use at least 6 characters for the password.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Something went wrong. Try again.';
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim(), pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      final guest = auth.currentUser;
      if (_signUp && guest != null && guest.isAnonymous) {
        // keep everything the guest already logged
        await guest.linkWithCredential(EmailAuthProvider.credential(email: email, password: pass));
        await guest.reload();
      } else if (_signUp) {
        await auth.createUserWithEmailAndPassword(email: email, password: pass);
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: pass);
      }
      if (widget.popOnDone && mounted) {
        toast(context, _signUp ? 'Account saved. Your data is safe.' : 'Logged in');
        Navigator.of(context).pop(true);
        return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Type your email first, then tap "Forgot password".');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) toast(context, 'Reset link sent to $email');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: widget.popOnDone ? AppBar(backgroundColor: Colors.transparent) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CustomPaint(
                      size: const Size(84, 84),
                      painter: SplashLogoPainter(rim: 0.75, dots: const [1, 1, 1], p: p),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('CalDay',
                      textAlign: TextAlign.center, style: display(context, 26)),
                  const SizedBox(height: 6),
                  Muted(
                      widget.saveGuest
                          ? 'Save your data with an email so you never lose it.'
                          : (widget.popOnDone ? 'Log in to your account.' : 'Snap your food. Know your calories and protein.'),
                      size: 15,
                      align: TextAlign.center),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_signUp ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _signUp = !_signUp;
                              _error = null;
                            }),
                    child: Text(_signUp ? 'I already have an account' : 'New here? Create an account'),
                  ),
                  if (!_signUp)
                    TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password')),
                  if (!widget.popOnDone) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Divider(color: p.line)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Muted('or', size: 13)),
                    Expanded(child: Divider(color: p.line)),
                  ]),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _skip,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text('Skip for now'),
                  ),
                  const SizedBox(height: 6),
                  const Muted('You can add an email later in Profile to keep your data safe.', size: 12, align: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
