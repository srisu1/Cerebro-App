// Registration screen — split layout with branded panel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _agreed = false;

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
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  int _strength(String pw) {
    if (pw.isEmpty) return 0;
    int s = 0;
    if (pw.length >= 8) s++;
    if (pw.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) s++;
    if (RegExp(r'[0-9]').hasMatch(pw)) s++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pw)) s++;
    return s.clamp(0, 5);
  }

  String _strengthLabel(int s) {
    const labels = ['', 'Weak', 'Fair', 'Good', 'Strong', 'Excellent'];
    return labels[s];
  }

  Color _strengthColor(int s) {
    // Was a `const colors = [...]` but the CerebroTheme accent getters
    // became runtime-resolved once dark mode landed, so this list can't
    // be const-evaluated anymore. Plain `final` is the drop-in.
    final colors = [
      CerebroTheme.creamDark,
      CerebroTheme.coral,
      CerebroTheme.gold,
      CerebroTheme.goldDark,
      CerebroTheme.sage,
      CerebroTheme.sageDark,
    ];
    return colors[s];
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please agree to the Terms and Privacy Policy first!',
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.white)),
        backgroundColor: CerebroTheme.gold,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
      return;
    }

    final ok = await ref.read(authProvider.notifier).register(
          email: _emailC.text.trim(),
          password: _passC.text,
          displayName: _nameC.text.trim(),
        );

    if (ok && mounted) {
      final loginOk = await ref.read(authProvider.notifier).login(
            email: _emailC.text.trim(),
            password: _passC.text,
          );
      if (loginOk && mounted) {
        context.go('/setup');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Account created! Please sign in.',
              style: GoogleFonts.nunito(fontSize: 13, color: Colors.white)),
          backgroundColor: CerebroTheme.sage,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ));
        context.go('/login');
      }
    }
  }

  void _showTermsPopup(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => _CuteDialog(
        accent: CerebroTheme.sage,
        title: title,
        body: Column(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: SingleChildScrollView(
                child: Text(content,
                    style: GoogleFonts.nunito(
                        color: CerebroTheme.brown,
                        fontSize: 13,
                        height: 1.7))),
          ),
          const SizedBox(height: 16),
          _CuteBtn(
              label: 'Got it!',
              color: CerebroTheme.sage,
              onTap: () => Navigator.pop(ctx)),
        ]),
      ),
    );
  }

  InputDecoration _softInput(
      {required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(
          color: CerebroTheme.creamDark,
          fontSize: 14,
          fontWeight: FontWeight.w500),
      filled: true,
      fillColor: const Color(0xFFFAF6F1),
      prefixIcon:
          Icon(icon, color: CerebroTheme.brown.withOpacity(0.55), size: 20),
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: CerebroTheme.creamDark, width: 2)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: CerebroTheme.creamDark, width: 2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: CerebroTheme.sage, width: 2.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: CerebroTheme.coral, width: 2)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: CerebroTheme.coral, width: 2.5)),
    );
  }

  //  BUILD
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final loading = auth.status == AuthStatus.loading;
    final wide = MediaQuery.of(context).size.width > 920;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F2),
      body: wide
          ? Row(children: [
              _brandPanel(),
              Expanded(child: _formPanel(auth, loading)),
            ])
          : _formPanel(auth, loading),
    );
  }

  //  LEFT BRAND PANEL  (sage green gradient)
  Widget _brandPanel() {
    return SizedBox(
      width: 380,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5EDE4), // warm cream top
              Color(0xFFE4F0E8), // sage tint bottom
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 60,
              left: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: CerebroTheme.sage.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: CerebroTheme.gold.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 200,
              right: 30,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: CerebroTheme.lavender.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1,
                color: CerebroTheme.outline.withOpacity(0.06),
              ),
            ),

            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _logoBadge(),
                    const SizedBox(height: 22),

                    Text('CEREBRO',
                        style: GoogleFonts.gaegu(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: CerebroTheme.outline,
                          letterSpacing: 3,
                        )),
                    const SizedBox(height: 6),
                    Text('Begin Your Student Quest',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CerebroTheme.brown,
                        )),

                    const SizedBox(height: 28),

                    Container(
                      width: 60,
                      height: 3,
                      decoration: BoxDecoration(
                        color: CerebroTheme.sage.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    const SizedBox(height: 28),

                    _featureChip(
                        Icons.school_rounded, 'Personalised Learning',
                        CerebroTheme.sage),
                    const SizedBox(height: 10),
                    _featureChip(
                        Icons.emoji_events_rounded, 'Earn XP & Level Up',
                        CerebroTheme.gold),
                    const SizedBox(height: 10),
                    _featureChip(
                        Icons.pets_rounded, 'Your Study Companion',
                        CerebroTheme.pinkPop),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoBadge() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8FD4AD), Color(0xFF5FB085)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CerebroTheme.outline, width: 4),
        boxShadow: [CerebroTheme.shadow3D],
      ),
      child: Center(
        child: Text('C',
            style: GoogleFonts.gaegu(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            )),
      ),
    );
  }

  Widget _featureChip(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: CerebroTheme.outline.withOpacity(0.08), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Text(text,
              style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CerebroTheme.outline)),
        ],
      ),
    );
  }

  //  RIGHT FORM PANEL
  Widget _formPanel(AuthState auth, bool loading) {
    final pwStr = _strength(_passC.text);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
        child: FadeTransition(
          opacity: _fade,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: CerebroTheme.creamDark, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  CerebroTheme.outline.withOpacity(0.06),
                              offset: const Offset(0, 2),
                              blurRadius: 0),
                        ],
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          color: CerebroTheme.brown, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Join the quest',
                      style: GoogleFonts.gaegu(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: CerebroTheme.outline,
                      )),
                  const SizedBox(height: 4),
                  Text('Create your account to get started',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CerebroTheme.brown,
                      )),
                  const SizedBox(height: 24),

                  _GoogleBtn(
                      label: 'Sign up with Google',
                      onTap: loading ? null : () async {
                        final ok = await ref
                            .read(authProvider.notifier)
                            .loginWithGoogle();
                        if (ok && mounted) {
                          context.go('/setup');
                        }
                      }),
                  const SizedBox(height: 20),

                  Row(children: [
                    Expanded(
                        child: Divider(
                            color: CerebroTheme.creamDark,
                            thickness: 1.5)),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or use email',
                          style: GoogleFonts.nunito(
                              color: CerebroTheme.brown,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                        child: Divider(
                            color: CerebroTheme.creamDark,
                            thickness: 1.5)),
                  ]),
                  const SizedBox(height: 20),

                  _label('Display Name'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameC,
                    style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: _softInput(
                        hint: 'How should we call you?',
                        icon: Icons.person_outlined),
                    validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                  ),
                  const SizedBox(height: 14),

                  _label('Email'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: _softInput(
                        hint: 'you@university.ac.uk',
                        icon: Icons.email_outlined),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _label('Password'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passC,
                    obscureText: _hidePass,
                    style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    onChanged: (_) => setState(() {}),
                    decoration: _softInput(
                      hint: 'Minimum 8 characters',
                      icon: Icons.lock_outlined,
                      suffix: IconButton(
                        icon: Icon(
                          _hidePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: CerebroTheme.brown.withOpacity(0.5),
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _hidePass = !_hidePass),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      if (v.length < 8) return 'At least 8 characters';
                      return null;
                    },
                  ),

                  if (_passC.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 8,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: CerebroTheme.creamDark
                                        .withOpacity(0.4),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: pwStr / 5,
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 300),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _strengthColor(pwStr)
                                              .withOpacity(0.7),
                                          _strengthColor(pwStr),
                                        ],
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(_strengthLabel(pwStr),
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _strengthColor(pwStr),
                                )),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  _label('Confirm Password'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmC,
                    obscureText: _hideConfirm,
                    style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: _softInput(
                      hint: 'Re-enter your password',
                      icon: Icons.lock_outlined,
                      suffix: IconButton(
                        icon: Icon(
                          _hideConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: CerebroTheme.brown.withOpacity(0.5),
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _hideConfirm = !_hideConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (v != _passC.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _agreed = !_agreed),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 200),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _agreed
                                ? CerebroTheme.sage
                                : Colors.white,
                            borderRadius:
                                BorderRadius.circular(9),
                            border: Border.all(
                              color: _agreed
                                  ? CerebroTheme.sageDark
                                  : CerebroTheme.creamDark,
                              width: 2.5,
                            ),
                            boxShadow: [
                              if (!_agreed)
                                BoxShadow(
                                    color: CerebroTheme.outline
                                        .withOpacity(0.06),
                                    offset:
                                        const Offset(0, 2),
                                    blurRadius: 0),
                            ],
                          ),
                          child: _agreed
                              ? const Icon(Icons.favorite,
                                  size: 15,
                                  color: Colors.white)
                              : Icon(Icons.favorite_border,
                                  size: 15,
                                  color:
                                      CerebroTheme.creamDark),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.only(top: 3),
                          child: Wrap(children: [
                            Text('I agree to the ',
                                style: GoogleFonts.nunito(
                                    color:
                                        CerebroTheme.brown,
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w600)),
                            GestureDetector(
                              onTap: () => _showTermsPopup(
                                  'Terms of Service',
                                  _termsText),
                              child: Text('Terms',
                                  style: GoogleFonts.nunito(
                                      color: CerebroTheme
                                          .sageDark,
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w700,
                                      decoration:
                                          TextDecoration
                                              .underline,
                                      decorationColor:
                                          CerebroTheme
                                              .sageDark
                                              .withOpacity(
                                                  0.5))),
                            ),
                            Text(' and ',
                                style: GoogleFonts.nunito(
                                    color:
                                        CerebroTheme.brown,
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w600)),
                            GestureDetector(
                              onTap: () => _showTermsPopup(
                                  'Privacy Policy',
                                  _privacyText),
                              child: Text('Privacy Policy',
                                  style: GoogleFonts.nunito(
                                      color: CerebroTheme
                                          .sageDark,
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w700,
                                      decoration:
                                          TextDecoration
                                              .underline,
                                      decorationColor:
                                          CerebroTheme
                                              .sageDark
                                              .withOpacity(
                                                  0.5))),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),

                  if (auth.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            CerebroTheme.coral.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: CerebroTheme.coral
                                .withOpacity(0.4),
                            width: 1.5),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            color: CerebroTheme.coral,
                            size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(auth.errorMessage!,
                                style: GoogleFonts.nunito(
                                    color:
                                        CerebroTheme.coralDark,
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w600))),
                      ]),
                    ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: _CuteBtn(
                      label: 'Create Account',
                      color: CerebroTheme.sage,
                      onTap: loading ? null : _handleRegister,
                      loading: loading,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Text('Already have an account? ',
                              style: GoogleFonts.nunito(
                                  color: CerebroTheme.brown,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          GestureDetector(
                            onTap: () =>
                                context.go('/login'),
                            child: Text('Sign In',
                                style: GoogleFonts.nunito(
                                    color:
                                        CerebroTheme.sageDark,
                                    fontWeight:
                                        FontWeight.w800,
                                    fontSize: 14)),
                          ),
                        ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: CerebroTheme.outline));
}

//  SHARED WIDGETS

class _CuteDialog extends StatelessWidget {
  final Color accent;
  final String title;
  final Widget body;
  const _CuteDialog(
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
          border: Border.all(color: CerebroTheme.outline, width: 3),
          boxShadow: [
            BoxShadow(
                color: CerebroTheme.outline.withOpacity(0.14),
                offset: const Offset(0, 6),
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
                      style: GoogleFonts.gaegu(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white))),
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
                  padding: const EdgeInsets.all(20), child: body)),
        ]),
      ),
    );
  }
}

class _GoogleBtn extends StatefulWidget {
  final VoidCallback? onTap;
  final String label;
  const _GoogleBtn(
      {required this.onTap, this.label = 'Continue with Google'});
  @override
  State<_GoogleBtn> createState() => _GoogleBtnState();
}

class _GoogleBtnState extends State<_GoogleBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _p = true) : null,
      onTapUp: widget.onTap != null ? (_) {
        setState(() => _p = false);
        widget.onTap!();
      } : null,
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 50,
        transform: Matrix4.translationValues(0, _p ? 2 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CerebroTheme.creamDark, width: 2),
          boxShadow: [
            if (!_p)
              BoxShadow(
                  color: CerebroTheme.outline.withOpacity(0.08),
                  offset: const Offset(0, 3),
                  blurRadius: 0),
          ],
        ),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: CerebroTheme.outline.withOpacity(0.3),
                    width: 1.5)),
            child: Center(
                child: Text('G',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4285F4)))),
          ),
          const SizedBox(width: 10),
          Text(widget.label,
              style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CerebroTheme.outline)),
        ]),
      ),
    );
  }
}

class _CuteBtn extends StatefulWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;
  final bool loading;
  final bool small;
  const _CuteBtn({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.onTap,
    this.loading = false,
    this.small = false,
  });
  @override
  State<_CuteBtn> createState() => _CuteBtnState();
}

class _CuteBtnState extends State<_CuteBtn> {
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
              color: CerebroTheme.outline,
              width: widget.small ? 2.5 : 3),
          boxShadow: [
            if (!_p)
              BoxShadow(
                  color: CerebroTheme.outline.withOpacity(0.25),
                  offset: const Offset(0, 4),
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
                  style: GoogleFonts.nunito(
                      fontSize: widget.small ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      color: widget.textColor)),
        ),
      ),
    );
  }
}
