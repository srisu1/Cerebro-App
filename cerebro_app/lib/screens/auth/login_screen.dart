/// Pixel-matched to ui-prototype/login.html:
///   • Olive green (#58772f) background with cross-dot pattern
///   • White "game-card" with thick dark border + hard box-shadow
///   • Left panel: SVG illustration + brand block
///   • Right panel: Sign In / Register tabs, Bitroad titles, pink-accent buttons
///   • Inputs: thick dark borders, pink focus glow
///   • All functionality preserved from v5.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/services/api_service.dart';

//  CONSTANTS
const _termsText =
    'CEREBRO Terms of Service\n\nLast updated: February 2026\n\n'
    '1. Acceptance of Terms\nBy accessing or using CEREBRO, you agree to these Terms.\n\n'
    '2. Description of Service\nCEREBRO is an smart student companion for study tracking, '
    'health monitoring, and daily life management.\n\n'
    '3. User Accounts\nYou are responsible for your account security.\n\n'
    '4. Acceptable Use\nYou agree not to misuse the service.\n\n'
    '5. Modifications\nWe may modify these terms at any time.';

const _privacyText =
    'CEREBRO Privacy Policy\n\nLast updated: February 2026\n\n'
    '1. Information We Collect\nName, email, study habits, health data, avatar preferences.\n\n'
    '2. How We Use It\nPersonalized recommendations and cross-domain insights.\n\n'
    '3. Data Storage\nSecurely stored with industry-standard encryption.\n\n'
    '4. Your Rights\nExport or delete your data anytime.\n\n'
    '5. Contact\nsupport@cerebro-app.com';

//  LOGIN SCREEN
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _regFormKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _regNameC = TextEditingController();
  final _regEmailC = TextEditingController();
  final _regPassC = TextEditingController();
  final _regConfirmC = TextEditingController();
  bool _hidePass = true;
  bool _rememberMe = true;
  bool _isSignIn = true; // tab state

  late AnimationController _ac;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    _emailC.dispose();
    _passC.dispose();
    _regNameC.dispose();
    _regEmailC.dispose();
    _regPassC.dispose();
    _regConfirmC.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .login(email: _emailC.text.trim(), password: _passC.text);
    if (ok && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final setupDone =
          prefs.getBool(AppConstants.setupCompleteKey) ?? false;
      final avatarDone =
          prefs.getBool(AppConstants.avatarCreatedKey) ?? false;
      if (!setupDone) {
        context.go('/setup');
      } else if (!avatarDone) {
        context.go('/avatar-setup');
      } else {
        context.go('/home');
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_regFormKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
          email: _regEmailC.text.trim(),
          password: _regPassC.text,
          displayName: _regNameC.text.trim(),
        );
    if (ok && mounted) {
      // Auto-login after successful registration
      final loginOk = await ref.read(authProvider.notifier).login(
            email: _regEmailC.text.trim(),
            password: _regPassC.text,
          );
      if (loginOk && mounted) {
        context.go('/setup');
      } else if (mounted) {
        // Registration succeeded but auto-login failed — switch to sign in tab
        setState(() => _isSignIn = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Account created! Please sign in.',
              style: GoogleFonts.nunito(fontSize: 13, color: Colors.white)),
          backgroundColor: CerebroTheme.oliveDark,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    final ok = await ref.read(authProvider.notifier).loginWithGoogle();
    if (ok && mounted) {
      // Check if user has a password — if not, force them to set one
      try {
        final api = ref.read(apiServiceProvider);
        final meResponse = await api.get('/auth/me');
        final hasPassword = meResponse.data['has_password'] ?? true;

        if (!hasPassword && mounted) {
          context.go('/set-password');
          return;
        }
      } catch (_) {
        // If /me fails, continue normally — password check is best-effort
      }

      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final setupDone =
          prefs.getBool(AppConstants.setupCompleteKey) ?? false;
      final avatarDone =
          prefs.getBool(AppConstants.avatarCreatedKey) ?? false;
      if (!setupDone) {
        context.go('/setup');
      } else if (!avatarDone) {
        context.go('/avatar-setup');
      } else {
        context.go('/home');
      }
    }
  }

  void _showForgotPassword() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ForgotPasswordDialog(
        gameInput: _gameInput,
        parentContext: context,
        api: ref.read(apiServiceProvider),
      ),
    );
  }

  void _showTermsPopup(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => _GameDialog(
        accent: CerebroTheme.olive,
        title: title,
        body: Column(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: SingleChildScrollView(
                child: Text(content,
                    style: GoogleFonts.nunito(
                        color: CerebroTheme.text2,
                        fontSize: 13,
                        height: 1.7))),
          ),
          const SizedBox(height: 16),
          _GameBtn(
              label: 'Got it!',
              color: CerebroTheme.olive,
              textColor: CerebroTheme.text1,
              onTap: () => Navigator.pop(ctx)),
        ]),
      ),
    );
  }

  InputDecoration _gameInput(
      {required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(
          color: CerebroTheme.text3,
          fontSize: 14,
          fontWeight: FontWeight.w400),
      filled: true,
      fillColor: CerebroTheme.inputBg,
      prefixIcon:
          Icon(icon, color: CerebroTheme.text2.withOpacity(0.6), size: 20),
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: CerebroTheme.text1, width: 2.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: CerebroTheme.text1, width: 2.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: CerebroTheme.pinkAccent, width: 2.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: CerebroTheme.coral, width: 2.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: CerebroTheme.coral, width: 2.5)),
    );
  }

  //  BUILD
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final loading = auth.status == AuthStatus.loading;
    final wide = MediaQuery.of(context).size.width > 720;

    return Scaffold(
      backgroundColor: CerebroTheme.oliveDark,
      body: Stack(
        children: [
          Positioned.fill(child: _DotPattern()),

          // Matches HTML: body { padding:28px; display:flex; align-items:center; justify-content:center; }
          // .game-card { width:100%; height:100%; max-width:1400px; }
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 48, 36, 28),
              child: FadeTransition(
                opacity: _fade,
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 1400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: CerebroTheme.text1, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: CerebroTheme.text1.withOpacity(0.5),
                            offset: const Offset(8, 8),
                            blurRadius: 0),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: wide
                          ? Row(children: [
                              Expanded(flex: 46, child: _brandPanel()),
                              Container(width: 3, color: CerebroTheme.text1),
                              Expanded(flex: 54, child: _formPanel(auth, loading)),
                            ])
                          : SingleChildScrollView(
                              child: Column(children: [
                                SizedBox(
                                    height: 220,
                                    child: _brandPanel(compact: true)),
                                Container(height: 3, color: CerebroTheme.text1),
                                _formPanel(auth, loading),
                              ]),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  LEFT BRAND PANEL
  Widget _brandPanel({bool compact = false}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
          colors: [
            CerebroTheme.creamWarm,   // cream top
            CerebroTheme.greenPale,   // green-pale middle
            CerebroTheme.pinkLight,   // pink-light bottom
          ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: SizedBox(
                width: compact ? 550 : 800,
                height: compact ? 440 : 640,
                child: SvgPicture.asset(
                  'assets/illustrations/login_illustration.svg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 18 : 28,
                vertical: compact ? 14 : 22),
            decoration: const BoxDecoration(
              color: CerebroTheme.creamWarm,
              border: Border(
                  top: BorderSide(color: CerebroTheme.text1, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: 'Cerebro',
                    style: TextStyle(
                      fontFamily: 'Bitroad',
                      fontSize: compact ? 28 : 42,
                      color: CerebroTheme.text1,
                      height: 1,
                    ),
                  ),
                  TextSpan(
                    text: '.',
                    style: TextStyle(
                      fontFamily: 'Bitroad',
                      fontSize: compact ? 28 : 42,
                      color: CerebroTheme.text1,
                      height: 1,
                    ),
                  ),
                ])),
                const SizedBox(height: 4),
                Text('Your study companion',
                    style: GoogleFonts.gaegu(
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      color: CerebroTheme.text2,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //  RIGHT FORM PANEL
  Widget _formPanel(AuthState auth, bool loading) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabs(),
              const SizedBox(height: 22),

              if (_isSignIn)
                _signInView(auth, loading)
              else
                _registerView(auth, loading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: CerebroTheme.dividerGreen, width: 2)),
      ),
      child: Row(
        children: [
          _tabButton('Sign In', _isSignIn, () {
            if (!_isSignIn) setState(() => _isSignIn = true);
          }),
          const SizedBox(width: 24),
          _tabButton('Register', !_isSignIn, () {
            if (_isSignIn) setState(() => _isSignIn = false);
          }),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active
                  ? CerebroTheme.pinkAccent
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.gaegu(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: active
                  ? CerebroTheme.pinkAccentDeep
                  : CerebroTheme.text3,
            )),
      ),
    );
  }

  //  SIGN IN VIEW
  Widget _signInView(AuthState auth, bool loading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome Back',
              style: TextStyle(
                fontFamily: 'Bitroad',
                fontSize: 34,
                color: CerebroTheme.text1,
              )),
          const SizedBox(height: 4),
          Text('Sign in to continue your journey',
              style: GoogleFonts.gaegu(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CerebroTheme.text3,
              )),
          const SizedBox(height: 24),

          _formLabel('EMAIL'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailC,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: CerebroTheme.text1),
            decoration: _gameInput(
                hint: 'your email',
                icon: Icons.email_outlined),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _formLabel('PASSWORD'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passC,
            obscureText: _hidePass,
            style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: CerebroTheme.text1),
            decoration: _gameInput(
              hint: '•••••••',
              icon: Icons.lock_outlined,
              suffix: IconButton(
                icon: Icon(
                  _hidePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: CerebroTheme.text2.withOpacity(0.5),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _hidePass = !_hidePass),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () =>
                    setState(() => _rememberMe = !_rememberMe),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? false),
                        activeColor: CerebroTheme.pinkAccent,
                        side: const BorderSide(
                            color: CerebroTheme.text2, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Remember me',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: CerebroTheme.text2)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showForgotPassword,
                child: Text('Forgot password?',
                    style: GoogleFonts.nunito(
                      color: CerebroTheme.pinkAccentDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 22),

          if (auth.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: CerebroTheme.coralSoft.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: CerebroTheme.coralSoft, width: 2),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    color: CerebroTheme.coral, size: 18),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(auth.errorMessage!,
                        style: GoogleFonts.nunito(
                            color: CerebroTheme.text1,
                            fontSize: 13,
                            fontWeight: FontWeight.w600))),
              ]),
            ),

          SizedBox(
            width: double.infinity,
            child: _GameBtn(
              label: 'Sign In',
              color: CerebroTheme.pinkAccent,
              textColor: CerebroTheme.text1,
              onTap: loading ? null : _handleLogin,
              loading: loading,
              useBitroad: true,
            ),
          ),
          const SizedBox(height: 18),

          Row(children: [
            const Expanded(
                child: Divider(
                    color: CerebroTheme.dividerGreen, thickness: 1.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR CONTINUE WITH',
                  style: GoogleFonts.nunito(
                      color: CerebroTheme.text3,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
            const Expanded(
                child: Divider(
                    color: CerebroTheme.dividerGreen, thickness: 1.5)),
          ]),
          const SizedBox(height: 18),

          _GoogleGameBtn(
              onTap: loading ? null : _handleGoogleLogin),
          const SizedBox(height: 18),

          Center(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ",
                      style: GoogleFonts.nunito(
                          color: CerebroTheme.text2,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  GestureDetector(
                    onTap: () => setState(() => _isSignIn = false),
                    child: Text('Register',
                        style: GoogleFonts.nunito(
                            color: CerebroTheme.pinkAccentDeep,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ]),
          ),

          const SizedBox(height: 14),

          Center(
            child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text('By continuing, you agree to our ',
                      style: GoogleFonts.nunito(
                          color: CerebroTheme.text2.withOpacity(0.6),
                          fontSize: 11)),
                  GestureDetector(
                    onTap: () => _showTermsPopup(
                        'Terms of Service', _termsText),
                    child: Text('Terms',
                        style: GoogleFonts.nunito(
                            color: CerebroTheme.text2,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline)),
                  ),
                  Text(' and ',
                      style: GoogleFonts.nunito(
                          color: CerebroTheme.text2.withOpacity(0.6),
                          fontSize: 11)),
                  GestureDetector(
                    onTap: () => _showTermsPopup(
                        'Privacy Policy', _privacyText),
                    child: Text('Privacy Policy',
                        style: GoogleFonts.nunito(
                            color: CerebroTheme.text2,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline)),
                  ),
                ]),
          ),
        ],
      ),
    );
  }

  //  REGISTER VIEW
  Widget _registerView(AuthState auth, bool loading) {
    return Form(
      key: _regFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Get Started',
              style: TextStyle(
                fontFamily: 'Bitroad',
                fontSize: 34,
                color: CerebroTheme.text1,
              )),
          const SizedBox(height: 4),
          Text('Create your account and begin the quest',
              style: GoogleFonts.gaegu(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CerebroTheme.text3,
              )),
          const SizedBox(height: 24),

          _formLabel('FULL NAME'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regNameC,
            style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: CerebroTheme.text1),
            decoration: _gameInput(
                hint: 'your name', icon: Icons.person_outlined),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),

          _formLabel('EMAIL'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regEmailC,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: CerebroTheme.text1),
            decoration: _gameInput(
                hint: 'your email', icon: Icons.email_outlined),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _formLabel('PASSWORD'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regPassC,
            obscureText: true,
            style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: CerebroTheme.text1),
            decoration: _gameInput(
                hint: '•••••••', icon: Icons.lock_outlined),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _formLabel('CONFIRM PASSWORD'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regConfirmC,
            obscureText: true,
            style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: CerebroTheme.text1),
            decoration: _gameInput(
                hint: '•••••••', icon: Icons.lock_outlined),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _regPassC.text) return 'Passwords don\'t match';
              return null;
            },
          ),
          const SizedBox(height: 22),

          if (auth.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: CerebroTheme.coralSoft.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: CerebroTheme.coralSoft, width: 2),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    color: CerebroTheme.coral, size: 18),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(auth.errorMessage!,
                        style: GoogleFonts.nunito(
                            color: CerebroTheme.text1,
                            fontSize: 13,
                            fontWeight: FontWeight.w600))),
              ]),
            ),

          SizedBox(
            width: double.infinity,
            child: _GameBtn(
              label: 'Create Account',
              color: CerebroTheme.pinkAccent,
              textColor: CerebroTheme.text1,
              useBitroad: true,
              onTap: loading ? null : _handleRegister,
              loading: loading,
            ),
          ),
          const SizedBox(height: 18),

          Row(children: [
            const Expanded(
                child: Divider(
                    color: CerebroTheme.dividerGreen, thickness: 1.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR CONTINUE WITH',
                  style: GoogleFonts.nunito(
                      color: CerebroTheme.text3,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
            const Expanded(
                child: Divider(
                    color: CerebroTheme.dividerGreen, thickness: 1.5)),
          ]),
          const SizedBox(height: 18),

          _GoogleGameBtn(
              onTap: loading ? null : _handleGoogleLogin),
          const SizedBox(height: 18),

          Center(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ',
                      style: GoogleFonts.nunito(
                          color: CerebroTheme.text2,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  GestureDetector(
                    onTap: () => setState(() => _isSignIn = true),
                    child: Text('Sign In',
                        style: GoogleFonts.nunito(
                            color: CerebroTheme.pinkAccentDeep,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ]),
          ),
        ],
      ),
    );
  }

  Widget _formLabel(String text) => Text(text,
      style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: CerebroTheme.text2,
          letterSpacing: 0.5));
}

//  DOT PATTERN BACKGROUND
class _DotPattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotPatternPainter(),
      size: Size.infinite,
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CerebroTheme.greenPale.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const radius = 1.2;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
        // Offset dots (cross pattern)
        canvas.drawCircle(
            Offset(x + spacing / 2, y + spacing / 2), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//  SHARED WIDGETS

class _GameDialog extends StatelessWidget {
  final Color accent;
  final String title;
  final Widget body;
  const _GameDialog(
      {required this.accent, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: CerebroTheme.text1, width: 3),
          boxShadow: [
            BoxShadow(
                color: CerebroTheme.text1.withOpacity(0.5),
                offset: const Offset(6, 6),
                blurRadius: 0),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
            decoration: BoxDecoration(
              color: accent,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(children: [
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontFamily: 'Bitroad',
                          fontSize: 22,
                          color: CerebroTheme.text1))),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
            ]),
          ),
          Flexible(
              child:
                  Padding(padding: const EdgeInsets.all(20), child: body)),
        ]),
      ),
    );
  }
}

class _GoogleGameBtn extends StatefulWidget {
  final VoidCallback? onTap;
  const _GoogleGameBtn({required this.onTap});
  @override
  State<_GoogleGameBtn> createState() => _GoogleGameBtnState();
}

class _GoogleGameBtnState extends State<_GoogleGameBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _p = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _p = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 52,
        transform: Matrix4.translationValues(0, _p ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CerebroTheme.text1, width: 2.5),
          boxShadow: [
            if (!_p)
              BoxShadow(
                  color: CerebroTheme.text1,
                  offset: const Offset(4, 4),
                  blurRadius: 0),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Google "G" icon
          SizedBox(
            width: 20,
            height: 20,
            child: CustomPaint(painter: _GoogleLogoPainter()),
          ),
          const SizedBox(width: 10),
          Text('Google',
              style: TextStyle(
                  fontFamily: 'Bitroad',
                  fontSize: 16,
                  color: CerebroTheme.text1)),
        ]),
      ),
    );
  }
}

class _GameBtn extends StatefulWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;
  final bool loading;
  final bool small;
  final bool useBitroad;
  const _GameBtn({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.onTap,
    this.loading = false,
    this.small = false,
    this.useBitroad = false,
  });
  @override
  State<_GameBtn> createState() => _GameBtnState();
}

class _GameBtnState extends State<_GameBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: widget.small ? 44 : 52,
        transform: Matrix4.translationValues(0, _p ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: CerebroTheme.text1,
              width: 2.5),
          boxShadow: [
            if (!_p)
              BoxShadow(
                  color: CerebroTheme.text1,
                  offset: const Offset(4, 4),
                  blurRadius: 0),
          ],
        ),
        child: Center(
          child: widget.loading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: widget.textColor))
              : Text(widget.label,
                  style: widget.useBitroad
                      ? TextStyle(
                          fontFamily: 'Bitroad',
                          fontSize: widget.small ? 14 : 16,
                          color: widget.textColor)
                      : GoogleFonts.nunito(
                          fontSize: widget.small ? 14 : 16,
                          fontWeight: FontWeight.w800,
                          color: widget.textColor)),
        ),
      ),
    );
  }
}

//  FORGOT PASSWORD DIALOG (3-step flow)
class _ForgotPasswordDialog extends StatefulWidget {
  final InputDecoration Function({required String hint, required IconData icon, Widget? suffix}) gameInput;
  final BuildContext parentContext;
  final ApiService api;

  const _ForgotPasswordDialog({
    required this.gameInput,
    required this.parentContext,
    required this.api,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  // Steps: 0 = enter email, 1 = enter code, 2 = new password, 3 = success
  int _step = 0;
  bool _loading = false;
  String? _error;
  String _email = '';

  final _emailC = TextEditingController();
  final _codeC = TextEditingController();
  final _newPassC = TextEditingController();
  final _confirmPassC = TextEditingController();
  bool _hidePass = true;

  @override
  void dispose() {
    _emailC.dispose();
    _codeC.dispose();
    _newPassC.dispose();
    _confirmPassC.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailC.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await widget.api.post('/auth/forgot-password', data: {'email': email});
      _email = email;
      setState(() { _step = 1; _loading = false; });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeC.text.trim();
    final newPass = _newPassC.text;
    final confirmPass = _confirmPassC.text;

    if (code.isEmpty || code.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }
    if (newPass.isEmpty || newPass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'Passwords don\'t match');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await widget.api.post('/auth/reset-password', data: {
        'email': _email,
        'reset_code': code,
        'new_password': newPass,
      });
      setState(() { _step = 3; _loading = false; });
    } catch (e) {
      String msg = 'Reset failed. Please check your code and try again.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        }
      }
      setState(() { _loading = false; _error = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: CerebroTheme.text1, width: 3),
          boxShadow: [
            BoxShadow(
                color: CerebroTheme.text1.withOpacity(0.5),
                offset: const Offset(6, 6),
                blurRadius: 0),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
            decoration: BoxDecoration(
              color: _step == 3 ? CerebroTheme.sage : CerebroTheme.pinkAccent,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(children: [
              Expanded(
                  child: Text(
                      _step == 0
                          ? 'Forgot Password'
                          : _step == 1
                              ? 'Enter Reset Code'
                              : _step == 3
                                  ? 'All Done!'
                                  : 'Forgot Password',
                      style: TextStyle(
                          fontFamily: 'Bitroad',
                          fontSize: 22,
                          color: CerebroTheme.text1))),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
            ]),
          ),

          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildStep(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) return _stepEmail();
    if (_step == 1) return _stepCode();
    if (_step == 3) return _stepSuccess();
    return const SizedBox.shrink();
  }

  Widget _stepEmail() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text("Enter your email address and we'll send you a reset code.",
          style: GoogleFonts.nunito(
              color: CerebroTheme.text2, fontSize: 14, height: 1.5)),
      const SizedBox(height: 14),
      TextField(
          controller: _emailC,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.nunito(fontSize: 14),
          decoration: widget.gameInput(
              hint: 'your email', icon: Icons.email_outlined)),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!,
            style: GoogleFonts.nunito(
                color: CerebroTheme.coral,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
            child: _GameBtn(
                label: 'Cancel',
                color: CerebroTheme.dividerGreen,
                textColor: CerebroTheme.text1,
                onTap: () => Navigator.pop(context),
                small: true)),
        const SizedBox(width: 10),
        Expanded(
            child: _GameBtn(
                label: 'Send Code',
                color: CerebroTheme.pinkAccent,
                textColor: CerebroTheme.text1,
                loading: _loading,
                onTap: _loading ? null : _requestCode,
                small: true)),
      ]),
    ]);
  }

  Widget _stepCode() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text("A 6-digit reset code was sent to your email. Enter it below with your new password.",
          style: GoogleFonts.nunito(
              color: CerebroTheme.text2, fontSize: 14, height: 1.5)),
      const SizedBox(height: 14),

      // Reset code field
      TextField(
          controller: _codeC,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: CerebroTheme.text1),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            hintStyle: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                letterSpacing: 8,
                color: CerebroTheme.text3.withOpacity(0.4)),
            filled: true,
            fillColor: CerebroTheme.inputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: CerebroTheme.text1, width: 2.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: CerebroTheme.text1, width: 2.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: CerebroTheme.pinkAccent, width: 2.5)),
          )),
      const SizedBox(height: 14),

      // New password
      TextField(
          controller: _newPassC,
          obscureText: _hidePass,
          style: GoogleFonts.nunito(fontSize: 14, color: CerebroTheme.text1),
          decoration: widget.gameInput(
            hint: 'New password (min 8 chars)',
            icon: Icons.lock_outlined,
            suffix: IconButton(
              icon: Icon(
                _hidePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: CerebroTheme.text2.withOpacity(0.5),
                size: 20,
              ),
              onPressed: () => setState(() => _hidePass = !_hidePass),
            ),
          )),
      const SizedBox(height: 12),

      // Confirm password
      TextField(
          controller: _confirmPassC,
          obscureText: true,
          style: GoogleFonts.nunito(fontSize: 14, color: CerebroTheme.text1),
          decoration: widget.gameInput(
              hint: 'Confirm password', icon: Icons.lock_outlined)),

      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!,
            style: GoogleFonts.nunito(
                color: CerebroTheme.coral,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
            child: _GameBtn(
                label: 'Back',
                color: CerebroTheme.dividerGreen,
                textColor: CerebroTheme.text1,
                onTap: () => setState(() { _step = 0; _error = null; }),
                small: true)),
        const SizedBox(width: 10),
        Expanded(
            child: _GameBtn(
                label: 'Reset',
                color: CerebroTheme.pinkAccent,
                textColor: CerebroTheme.text1,
                loading: _loading,
                onTap: _loading ? null : _resetPassword,
                small: true)),
      ]),
    ]);
  }

  Widget _stepSuccess() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: CerebroTheme.sage.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: CerebroTheme.text1, width: 2.5),
        ),
        child: const Icon(Icons.check_rounded,
            color: CerebroTheme.sageDark, size: 36),
      ),
      const SizedBox(height: 16),
      Text('Password reset successfully!',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
              color: CerebroTheme.text1,
              fontSize: 16,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
              color: CerebroTheme.text2, fontSize: 14, height: 1.4)),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: _GameBtn(
            label: 'Back to Sign In',
            color: CerebroTheme.sage,
            textColor: CerebroTheme.text1,
            onTap: () => Navigator.pop(context),
            small: true),
      ),
    ]);
  }
}

//  GOOGLE LOGO PAINTER
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Red
    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(w * 0.5, h * 0.198)
      ..cubicTo(w * 0.574, h * 0.198, w * 0.640, h * 0.223,
          w * 0.692, h * 0.273)
      ..lineTo(w * 0.835, h * 0.130)
      ..cubicTo(w * 0.748, h * 0.050, w * 0.635, 0, w * 0.5, 0)
      ..cubicTo(w * 0.305, 0, w * 0.136, h * 0.112, w * 0.053, h * 0.275)
      ..lineTo(w * 0.220, h * 0.404)
      ..cubicTo(w * 0.259, h * 0.286, w * 0.370, h * 0.198, w * 0.5, h * 0.198)
      ..close();
    canvas.drawPath(redPath, redPaint);

    // Blue
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(w * 0.979, h * 0.511)
      ..cubicTo(w * 0.979, h * 0.479, w * 0.976, h * 0.447, w * 0.971, h * 0.417)
      ..lineTo(w * 0.5, h * 0.417)
      ..lineTo(w * 0.5, h * 0.604)
      ..lineTo(w * 0.770, h * 0.604)
      ..cubicTo(w * 0.758, h * 0.666, w * 0.723, h * 0.718,
          w * 0.670, h * 0.754)
      ..lineTo(w * 0.831, h * 0.879)
      ..cubicTo(w * 0.925, h * 0.792, w * 0.979, h * 0.663, w * 0.979, h * 0.511)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Yellow
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(w * 0.219, h * 0.596)
      ..cubicTo(w * 0.206, h * 0.558, w * 0.198, h * 0.518,
          w * 0.198, h * 0.477)
      ..cubicTo(w * 0.198, h * 0.436, w * 0.206, h * 0.397,
          w * 0.219, h * 0.358)
      ..lineTo(w * 0.053, h * 0.229)
      ..cubicTo(w * 0.019, h * 0.308, 0, h * 0.395, 0, h * 0.490)
      ..cubicTo(0, h * 0.585, w * 0.019, h * 0.671, w * 0.053, h * 0.750)
      ..lineTo(w * 0.219, h * 0.596)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Green
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(w * 0.5, h)
      ..cubicTo(w * 0.635, h, w * 0.749, h * 0.956, w * 0.831, h * 0.879)
      ..lineTo(w * 0.670, h * 0.754)
      ..cubicTo(w * 0.625, h * 0.784, w * 0.568, h * 0.802, w * 0.5, h * 0.802)
      ..cubicTo(w * 0.370, h * 0.802, w * 0.259, h * 0.714,
          w * 0.219, h * 0.596)
      ..lineTo(w * 0.053, h * 0.725)
      ..cubicTo(w * 0.136, h * 0.888, w * 0.305, h, w * 0.5, h)
      ..close();
    canvas.drawPath(greenPath, greenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
