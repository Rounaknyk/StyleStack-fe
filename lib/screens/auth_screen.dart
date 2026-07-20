import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../config/brand_logo.dart';
import '../providers/auth_provider.dart';
import 'privacy_policy_screen.dart';

enum _AuthPanel { chooser, phone, email }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();

  _AuthPanel _panel = _AuthPanel.chooser;
  bool _signUp = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _showPanel(_AuthPanel panel) {
    context.read<AuthProvider>().clearError();
    setState(() => _panel = panel);
  }

  Future<void> _submitEmail() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    await context.read<AuthProvider>().authenticateEmail(
      email: _email.text,
      password: _password.text,
      createAccount: _signUp,
    );
  }

  Future<void> _sendOtp() async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().sendPhoneOtp(_phone.text);
  }

  Future<void> _verifyOtp() async {
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().verifyPhoneOtp(_otp.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(DesignSystem.spacingXl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - DesignSystem.spacingXl * 2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandHeader(compact: _panel != _AuthPanel.chooser),
                      SizedBox(
                        height: _panel == _AuthPanel.chooser
                            ? DesignSystem.spacingxxxl
                            : DesignSystem.spacingXxl,
                      ),
                      AnimatedSwitcher(
                        duration: DesignSystem.transitionStandard,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: switch (_panel) {
                          _AuthPanel.chooser => _buildChooser(auth),
                          _AuthPanel.phone => _buildPhone(auth),
                          _AuthPanel.email => _buildEmail(auth),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChooser(AuthProvider auth) {
    return Column(
      key: const ValueKey('auth-chooser'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your personal stylist,\n+built around your wardrobe.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: DesignSystem.spacingSm),
        Text(
          'Sign in once. We’ll make getting dressed feel effortless.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: DesignSystem.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: DesignSystem.spacingXxl),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: auth.loading ? null : auth.authenticateWithGoogle,
            child: auth.loading
                ? const _ButtonSpinner()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          'assets/images/google_icon_logo.svg',
                          width: 18,
                          height: 18,
                          semanticsLabel: 'Google',
                        ),
                      ),
                      const SizedBox(width: DesignSystem.spacingMd),
                      const Text('Continue with Google'),
                      const SizedBox(width: DesignSystem.spacingMd),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'FASTEST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: DesignSystem.spacingMd),
        _AuthOptionButton(
          icon: Icons.phone_iphone_rounded,
          title: 'Continue with Phone',
          subtitle: 'Quick OTP verification for India',
          enabled: !auth.loading,
          onPressed: () => _showPanel(_AuthPanel.phone),
        ),
        const SizedBox(height: DesignSystem.spacingMd),
        _AuthOptionButton(
          icon: Icons.mail_outline_rounded,
          title: 'Continue with Email',
          subtitle: 'Use your email and password',
          enabled: !auth.loading,
          onPressed: () => _showPanel(_AuthPanel.email),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: DesignSystem.spacingLg),
          _AuthError(message: auth.error!),
        ],
        const SizedBox(height: DesignSystem.spacingXl),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
          ),
          child: Text(
            'Read how StyleStack handles your data in our Privacy Policy.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DesignSystem.textSecondary,
              decoration: TextDecoration.underline,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhone(AuthProvider auth) {
    final awaitingCode = auth.isAwaitingPhoneCode;
    return Column(
      key: const ValueKey('phone-auth'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: awaitingCode ? 'Check your messages' : 'Continue with phone',
          subtitle: awaitingCode
              ? 'Enter the 6-digit code sent to ${auth.phoneNumber ?? 'your phone'}.'
              : 'We’ll text you a one-time code. Standard SMS rates may apply.',
          onBack: auth.loading
              ? null
              : () {
                  auth.resetPhoneFlow();
                  _otp.clear();
                  _showPanel(_AuthPanel.chooser);
                },
        ),
        const SizedBox(height: DesignSystem.spacingXxl),
        AnimatedSwitcher(
          duration: DesignSystem.transitionStandard,
          child: awaitingCode
              ? Form(
                  key: _otpFormKey,
                  child: Column(
                    key: const ValueKey('otp-form'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('phone-otp-field'),
                        controller: _otp,
                        enabled: !auth.loading,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                          hintText: '••••••',
                          prefixIcon: Icon(Icons.password_rounded),
                        ),
                        validator: (value) => value?.length == 6
                            ? null
                            : 'Enter the 6-digit code',
                        onFieldSubmitted: (_) => _verifyOtp(),
                      ),
                      const SizedBox(height: DesignSystem.spacingLg),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: auth.loading ? null : _verifyOtp,
                          child: auth.loading
                              ? const _ButtonSpinner()
                              : const Text('Verify and continue'),
                        ),
                      ),
                      const SizedBox(height: DesignSystem.spacingSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Didn’t receive it?',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: auth.canResendPhoneCode
                                ? () {
                                    _otp.clear();
                                    auth.resendPhoneOtp();
                                  }
                                : null,
                            child: const Text('Resend code'),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: auth.loading
                            ? null
                            : () {
                                auth.resetPhoneFlow();
                                _otp.clear();
                              },
                        child: const Text('Use a different number'),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _phoneFormKey,
                  child: Column(
                    key: const ValueKey('phone-form'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('phone-number-field'),
                        controller: _phone,
                        enabled: !auth.loading,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Mobile number',
                          hintText: '98765 43210',
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(left: 16, right: 10),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                '+91',
                                style: TextStyle(
                                  color: DesignSystem.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        validator: (value) => value?.length == 10
                            ? null
                            : 'Enter a valid 10-digit number',
                        onFieldSubmitted: (_) => _sendOtp(),
                      ),
                      const SizedBox(height: DesignSystem.spacingLg),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: auth.loading ? null : _sendOtp,
                          child: auth.loading
                              ? const _ButtonSpinner()
                              : const Text('Send verification code'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: DesignSystem.spacingLg),
          _AuthError(message: auth.error!),
        ],
      ],
    );
  }

  Widget _buildEmail(AuthProvider auth) {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email-auth'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: _signUp ? 'Create your account' : 'Welcome back',
            subtitle: _signUp
                ? 'Start building a wardrobe that works harder for you.'
                : 'Sign in to continue to your personal stylist.',
            onBack: auth.loading ? null : () => _showPanel(_AuthPanel.chooser),
          ),
          const SizedBox(height: DesignSystem.spacingXxl),
          TextFormField(
            key: const Key('email-field'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            enabled: !auth.loading,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'hello@example.com',
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              return email.contains('@') && email.contains('.')
                  ? null
                  : 'Enter a valid email';
            },
          ),
          const SizedBox(height: DesignSystem.spacingLg),
          TextFormField(
            key: const Key('password-field'),
            controller: _password,
            obscureText: _obscure,
            enabled: !auth.loading,
            textInputAction: TextInputAction.done,
            autofillHints: _signUp
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            validator: (value) =>
                (value?.length ?? 0) >= 6 ? null : 'Use at least 6 characters',
            onFieldSubmitted: (_) => _submitEmail(),
          ),
          if (auth.error != null) ...[
            const SizedBox(height: DesignSystem.spacingLg),
            _AuthError(message: auth.error!),
          ],
          const SizedBox(height: DesignSystem.spacingXl),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: auth.loading ? null : _submitEmail,
              child: auth.loading
                  ? const _ButtonSpinner()
                  : Text(_signUp ? 'Create account' : 'Sign in'),
            ),
          ),
          const SizedBox(height: DesignSystem.spacingSm),
          TextButton(
            onPressed: auth.loading
                ? null
                : () {
                    auth.clearError();
                    setState(() => _signUp = !_signUp);
                  },
            child: Text(
              _signUp
                  ? 'Already have an account? Sign in'
                  : 'New to StyleStack? Create an account',
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: DesignSystem.transitionStandard,
          width: compact ? 58 : 76,
          height: compact ? 58 : 76,
          decoration: BoxDecoration(
            color: DesignSystem.surface,
            borderRadius: BorderRadius.circular(
              compact ? DesignSystem.radiusLg : DesignSystem.radiusXl,
            ),
            border: Border.all(color: DesignSystem.border),
            boxShadow: DesignSystem.shadowSoft,
          ),
          child: StyleStackLogo(size: compact ? 48 : 62),
        ),
        const SizedBox(height: DesignSystem.spacingLg),
        Text(
          'StyleStack',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: DesignSystem.spacingSm),
          Text(
            'Your closet, styled with intention.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DesignSystem.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: DesignSystem.spacingLg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: DesignSystem.spacingSm,
            runSpacing: DesignSystem.spacingSm,
            children: const [
              _BrandPill(icon: Icons.checkroom_rounded, label: 'Your closet'),
              _BrandPill(icon: Icons.auto_awesome_rounded, label: 'Your edit'),
            ],
          ),
        ],
      ],
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DesignSystem.secondaryLight.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: DesignSystem.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: DesignSystem.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.filledTonal(
          tooltip: 'Back to sign-in options',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(height: DesignSystem.spacingLg),
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: DesignSystem.spacingSm),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: DesignSystem.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _AuthOptionButton extends StatelessWidget {
  const _AuthOptionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignSystem.surface,
      borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
        child: Ink(
          height: 66,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.spacingLg,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: DesignSystem.border),
            borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
          ),
          child: Row(
            children: [
              Icon(icon, color: DesignSystem.primary),
              const SizedBox(width: DesignSystem.spacingLg),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: DesignSystem.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(DesignSystem.spacingMd),
        decoration: BoxDecoration(
          color: DesignSystem.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
          border: Border.all(color: DesignSystem.error.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: DesignSystem.error,
              size: DesignSystem.iconSizeMedium,
            ),
            const SizedBox(width: DesignSystem.spacingMd),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignSystem.error,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}
