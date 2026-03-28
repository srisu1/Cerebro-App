// Set-password screen — shown after Google OAuth when no password exists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});
  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _loading = false;
  String? _error;

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
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _handleSetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/auth/set-password', data: {
        'password': _passC.text,
      });

      if (!mounted) return;

      // Password set successfully — continue to setup/avatar/home
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
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to set password. Please try again.';
      });
    }
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
              BorderSide(color: CerebroTheme.text1, width: 2.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: CerebroTheme.text1, width: 2.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: CerebroTheme.pinkAccent, width: 2.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: CerebroTheme.coral, width: 2.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: CerebroTheme.coral, width: 2.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CerebroTheme.oliveDark,
      body: Stack(
        children: [
          Positioned.fill(child: _DotPattern()),

          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 48, 36, 28),
              child: FadeTransition(
                opacity: _fade,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: CerebroTheme.text1, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: CerebroTheme.text1.withOpacity(0.5),
                            offset: const Offset(8, 8),
                            blurRadius: 0),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 28),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  CerebroTheme.pinkAccent,
                                  CerebroTheme.pinkAccentDeep,
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: CerebroTheme.text1, width: 2.5),
                                  ),
                                  child: Icon(Icons.lock_outlined,
                                      color: CerebroTheme.text1, size: 28),
                                ),
                                const SizedBox(height: 16),
                                Text('Set Your Password',
                                    style: TextStyle(
                                      fontFamily: 'Bitroad',
                                      fontSize: 28,
                                      color: CerebroTheme.text1,
                                    )),
                                const SizedBox(height: 6),
                                Text(
                                    'You signed in with Google — please set a password so you can also log in with email.',
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: CerebroTheme.text1
                                          .withOpacity(0.75),
                                      height: 1.4,
                                    )),
                              ],
                            ),
                          ),

                          Container(
                              height: 3, color: CerebroTheme.text1),

                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _formLabel('NEW PASSWORD'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _passC,
                                    obscureText: _hidePass,
                                    style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: CerebroTheme.text1),
                                    decoration: _gameInput(
                                      hint: 'At least 8 characters',
                                      icon: Icons.lock_outlined,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _hidePass
                                              ? Icons
                                                  .visibility_off_outlined
                                              : Icons
                                                  .visibility_outlined,
                                          color: CerebroTheme.text2
                                              .withOpacity(0.5),
                                          size: 20,
                                        ),
                                        onPressed: () => setState(
                                            () => _hidePass = !_hidePass),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Password is required';
                                      }
                                      if (v.length < 8) {
                                        return 'At least 8 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  _formLabel('CONFIRM PASSWORD'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _confirmC,
                                    obscureText: _hideConfirm,
                                    style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: CerebroTheme.text1),
                                    decoration: _gameInput(
                                      hint: 'Re-enter your password',
                                      icon: Icons.lock_outlined,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _hideConfirm
                                              ? Icons
                                                  .visibility_off_outlined
                                              : Icons
                                                  .visibility_outlined,
                                          color: CerebroTheme.text2
                                              .withOpacity(0.5),
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() =>
                                            _hideConfirm = !_hideConfirm),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please confirm your password';
                                      }
                                      if (v != _passC.text) {
                                        return 'Passwords don\'t match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 22),

                                  if (_error != null)
                                    Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: CerebroTheme.coralSoft
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: CerebroTheme.coralSoft,
                                            width: 2),
                                      ),
                                      child: Row(children: [
                                        Icon(Icons.info_outline,
                                            color: CerebroTheme.coral,
                                            size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Text(_error!,
                                                style: GoogleFonts.nunito(
                                                    color:
                                                        CerebroTheme.text1,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600))),
                                      ]),
                                    ),

                                  SizedBox(
                                    width: double.infinity,
                                    child: _GameBtn(
                                      label: 'Set Password & Continue',
                                      color: CerebroTheme.pinkAccent,
                                      textColor: CerebroTheme.text1,
                                      onTap: _loading
                                          ? null
                                          : _handleSetPassword,
                                      loading: _loading,
                                      useBitroad: true,
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  Center(
                                    child: Text(
                                        'This lets you sign in with email + password too',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: CerebroTheme.text3,
                                        )),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  Widget _formLabel(String text) => Text(text,
      style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: CerebroTheme.text2,
          letterSpacing: 0.5));
}

//  DOT PATTERN BACKGROUND (same as login)
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
        canvas.drawCircle(
            Offset(x + spacing / 2, y + spacing / 2), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//  GAME BUTTON (same style as login)
class _GameBtn extends StatefulWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;
  final bool loading;
  final bool useBitroad;
  const _GameBtn({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.onTap,
    this.loading = false,
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
        height: 52,
        transform: Matrix4.translationValues(0, _p ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
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
                          fontSize: 16,
                          color: widget.textColor)
                      : GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: widget.textColor)),
        ),
      ),
    );
  }
}
