import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'components.dart';
import 'services.dart';
import 'theme.dart';

// ======================= floating food & drinks =======================
class _FloatItem {
  final Widget child;
  final double x, y, phase; // x, y: fractions of the area; phase: 0..1
  const _FloatItem(this.child, this.x, this.y, this.phase);
}

typedef _Emoji = (String, double, double, double, double); // emoji, x, y, phase, size

// header (login / register pages): food and drinks only
const List<_Emoji> _headerEmojis = [
  ('🍔', .10, .18, 0.00, 44), ('🍕', .78, .10, 0.20, 40), ('🍟', .86, .50, 0.45, 34), ('🍗', .05, .58, 0.70, 38),
  ('🥤', .64, .66, 0.10, 36), ('🍹', .36, .06, 0.55, 34), ('🍛', .44, .72, 0.85, 32),
];
// welcome page: big
const List<_Emoji> _bigEmojis = [
  ('🍔', .05, .04, 0.00, 86), ('🍕', .58, .02, 0.20, 78), ('🥤', .34, .20, 0.50, 70), ('🍟', .70, .30, 0.45, 72),
  ('🍗', .02, .34, 0.70, 76), ('🍹', .62, .56, 0.10, 70), ('🍛', .30, .50, 0.85, 80), ('🌯', .04, .64, 0.35, 66),
];

List<_FloatItem> _emojiItems(List<_Emoji> l) => [for (final e in l) _FloatItem(Text(e.$1, style: TextStyle(fontSize: e.$5)), e.$2, e.$3, e.$4)];

/// Pictures from the admin (config/welcome > images) float in the same big slots.
List<_FloatItem> _imageItems(List<String> urls) => [
      for (var i = 0; i < _bigEmojis.length; i++)
        _FloatItem(
          Container(
            width: _bigEmojis[i].$5 * 1.7,
            height: _bigEmojis[i].$5 * 1.7,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 16, offset: const Offset(0, 8))]),
            child: ClipOval(
              child: CachedNetworkImage(imageUrl: urls[i % urls.length], fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.white24)),
            ),
          ),
          _bigEmojis[i].$2, _bigEmojis[i].$3, _bigEmojis[i].$4,
        ),
    ];

class _FloatLayer extends StatefulWidget {
  final List<_FloatItem> items;
  const _FloatLayer({required this.items});
  @override
  State<_FloatLayer> createState() => _FloatLayerState();
}

class _FloatLayerState extends State<_FloatLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, box) => AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Stack(children: [
            for (final it in widget.items)
              Positioned(
                left: box.maxWidth * it.x + math.sin(2 * math.pi * (_c.value + it.phase)) * 10,
                top: box.maxHeight * it.y + math.cos(2 * math.pi * (_c.value + it.phase)) * 14,
                child: Transform.rotate(angle: math.sin(2 * math.pi * (_c.value + it.phase)) * .15, child: it.child),
              ),
          ]),
        ),
      );
}

/// Accepts an array of links, or a single text value with one or more links (separated by commas, spaces or new lines).
List<String> _asUrls(dynamic v) {
  final raw = v is List ? v : (v is String ? v.split(RegExp(r'[\s,]+')) : <dynamic>[]);
  return [for (final i in raw) if ('$i'.trim().startsWith('http')) '$i'.trim()];
}

const _redGradient = BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7F1414), AppTheme.brand], begin: Alignment.topLeft, end: Alignment.bottomRight));

class _Wordmark extends StatelessWidget {
  final double size;
  const _Wordmark(this.size);
  @override
  Widget build(BuildContext context) => Text.rich(
        const TextSpan(children: [
          TextSpan(text: 'Bite'),
          TextSpan(text: ' & ', style: TextStyle(fontWeight: FontWeight.w400, fontStyle: FontStyle.italic)),
          TextSpan(text: 'Sip'),
        ]),
        style: TextStyle(color: Colors.white, fontSize: size, fontWeight: FontWeight.w900, letterSpacing: -1),
      );
}

// ======================= 1. Welcome page (the first page) =======================
/// Content comes from Firestore doc config/welcome: title, subtitle, videoUrl, images (list of picture URLs).
/// Priority: video, then pictures, then the default food and drink animation.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  Widget _btn(String t, bool filled, VoidCallback f) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    const label = TextStyle(fontWeight: FontWeight.w900, fontSize: 16);
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: filled
          ? FilledButton(onPressed: f, style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.brand, shape: shape), child: Text(t, style: label))
          : OutlinedButton(onPressed: f, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 2), shape: shape), child: Text(t, style: label)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF7F1414),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.doc('config/welcome').snapshots(),
          builder: (_, s) {
            final d = s.data?.data() ?? {}; // if it cannot be read, the default animation is used
            final video = '${d['videoUrl'] ?? ''}'.trim();
            final images = _asUrls(d['images']);
            final title = '${d['title'] ?? ''}'.trim();
            final subtitle = '${d['subtitle'] ?? 'Food & drinks, delivered fast'}'.trim();
            return Stack(fit: StackFit.expand, children: [
              Container(decoration: _redGradient),
              if (video.isNotEmpty) ...[_WelcomeVideo(url: video), Container(color: Colors.black45)],
              if (video.isEmpty)
                Positioned.fill(
                  child: SafeArea(
                    child: FractionallySizedBox(
                      heightFactor: .62,
                      alignment: Alignment.topCenter,
                      child: _FloatLayer(items: images.isNotEmpty ? _imageItems(images) : _emojiItems(_bigEmojis)),
                    ),
                  ),
                ),
              SafeArea(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 40 * (1 - v)), child: child)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Center(child: title.isEmpty ? const _Wordmark(54) : Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1))),
                      const SizedBox(height: 8),
                      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 28),
                      _btn('Create account', true, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()))),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                          child: const Text.rich(
                            TextSpan(text: 'I already have an account? ', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 15), children: [
                              TextSpan(text: 'Sign in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: Colors.white)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}

class _WelcomeVideo extends StatefulWidget {
  final String url;
  const _WelcomeVideo({required this.url});
  @override
  State<_WelcomeVideo> createState() => _WelcomeVideoState();
}

class _WelcomeVideoState extends State<_WelcomeVideo> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      _c.setLooping(true);
      _c.setVolume(0);
      _c.play();
      if (mounted) setState(() => _ready = true);
    }).catchError((_) {});
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => !_ready
      ? const SizedBox.shrink()
      : SizedBox.expand(
          child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _c.value.size.width, height: _c.value.size.height, child: VideoPlayer(_c))),
        );
}

// ======================= 2. Login page and 3. Register page =======================
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => const _FormPage(reg: false);
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) => const _FormPage(reg: true);
}

class _FormPage extends StatefulWidget {
  final bool reg;
  const _FormPage({required this.reg});
  @override
  State<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<_FormPage> {
  final _k = GlobalKey<FormState>();
  final _n = TextEditingController(), _e = TextEditingController(), _p = TextEditingController();
  bool _busy = false;
  bool get _reg => widget.reg;
  StreamSubscription<User?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u != null && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _n.dispose();
    _e.dispose();
    _p.dispose();
    super.dispose();
  }

  String _msg(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try logging in.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'operation-not-allowed':
      case 'configuration-not-found':
        return 'Email sign-in is not switched on. In Firebase open Authentication > Sign-in method and enable Email/Password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_k.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_reg) {
        await AuthService.register(_n.text.trim(), _e.text.trim(), _p.text);
      } else {
        await AuthService.login(_e.text.trim(), _p.text);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) toast(context, _msg(e));
    } catch (e) {
      debugPrint('Auth error: $e');
      if (mounted) toast(context, kDebugMode ? 'Error: $e' : 'Something went wrong. Please try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _forgot() async {
    final email = _e.text.trim();
    if (!email.contains('@')) return toast(context, 'Type your email above first.');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) toast(context, 'Reset link sent to $email');
    } on FirebaseAuthException catch (e) {
      if (mounted) toast(context, _msg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kb = MediaQuery.of(context).viewInsets.bottom > 0;
    final heroH = kb ? 130.0 : (MediaQuery.of(context).size.height * 0.30).clamp(200.0, 280.0);
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(children: [
        Positioned(
          top: 0, left: 0, right: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            height: heroH,
            decoration: _redGradient,
            child: Stack(children: [
              Positioned.fill(child: _FloatLayer(items: _emojiItems(_headerEmojis))),
              SafeArea(child: Padding(padding: const EdgeInsets.only(bottom: 22), child: Center(child: _Wordmark(kb ? 30 : 40)))),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircleAvatar(backgroundColor: Colors.black38, child: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context))),
                ),
              ),
            ]),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          top: heroH - 32, left: 0, right: 0, bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 24, offset: const Offset(0, -6))],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_reg ? 'Create account' : 'Welcome back', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text(_reg ? 'Join us and get your favourite meals delivered.' : 'Log in to order your favourite meals.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 22),
                    Form(
                      key: _k,
                      child: Column(children: [
                        if (_reg) AppTextField(controller: _n, label: 'Full name', icon: Icons.person_outline_rounded, validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null),
                        AppTextField(controller: _e, label: 'Email', icon: Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress, validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email'),
                        AppTextField(controller: _p, label: 'Password', icon: Icons.lock_outline_rounded, obscure: true, validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null),
                      ]),
                    ),
                    if (!_reg) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _forgot, child: const Text('Forgot password?'))),
                    const SizedBox(height: 4),
                    AppButton(label: _reg ? 'Create account' : 'Log in', loading: _busy, onPressed: _submit),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => _reg ? const LoginScreen() : const RegisterScreen())),
                        child: Text(_reg ? 'Already have an account? Log in' : 'New here? Create an account'),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
