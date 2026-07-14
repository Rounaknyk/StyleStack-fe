import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthProvider>().authenticate(
      email: _email.text,
      password: _password.text,
      createAccount: _signUp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(DesignSystem.spacingXl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Center(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo and branding
                            Container(
                              padding: const EdgeInsets.all(
                                DesignSystem.spacingLg,
                              ),
                              decoration: BoxDecoration(
                                color: DesignSystem.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  DesignSystem.radiusXl,
                                ),
                              ),
                              child: const Icon(
                                Icons.checkroom_rounded,
                                size: 64,
                                color: DesignSystem.primary,
                              ),
                            ),
                            const SizedBox(height: DesignSystem.spacingXxl),

                            // Title
                            Text(
                              'StyleStack',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            const SizedBox(height: DesignSystem.spacingMd),

                            // Subtitle
                            Text(
                              _signUp
                                  ? 'Create your digital wardrobe'
                                  : 'Welcome back to your fashion space',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: DesignSystem.textSecondary),
                            ),
                            const SizedBox(height: DesignSystem.spacingxxxl),

                            // Email field
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              enabled: !auth.loading,
                              decoration: InputDecoration(
                                labelText: 'Email address',
                                prefixIcon: const Icon(Icons.email_outlined),
                                hintText: 'hello@example.com',
                              ),
                              validator: (value) =>
                                  value != null && value.contains('@')
                                  ? null
                                  : 'Enter a valid email',
                            ),
                            const SizedBox(height: DesignSystem.spacingLg),

                            // Password field
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              enabled: !auth.loading,
                              autofillHints: _signUp
                                  ? const [AutofillHints.newPassword]
                                  : const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                              validator: (value) => (value?.length ?? 0) >= 6
                                  ? null
                                  : 'Use at least 6 characters',
                              onFieldSubmitted: (_) => _submit(),
                            ),

                            // Error message
                            if (auth.error != null) ...[
                              const SizedBox(height: DesignSystem.spacingMd),
                              Container(
                                padding: const EdgeInsets.all(
                                  DesignSystem.spacingMd,
                                ),
                                decoration: BoxDecoration(
                                  color: DesignSystem.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    DesignSystem.radiusMd,
                                  ),
                                  border: Border.all(
                                    color: DesignSystem.error.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: DesignSystem.error,
                                      size: DesignSystem.iconSizeMedium,
                                    ),
                                    const SizedBox(
                                      width: DesignSystem.spacingMd,
                                    ),
                                    Expanded(
                                      child: Text(
                                        auth.error!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: DesignSystem.error,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: DesignSystem.spacingXxl),

                            // Primary button
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed: auth.loading ? null : _submit,
                                child: auth.loading
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        _signUp ? 'Create account' : 'Sign in',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: DesignSystem.spacingMd),

                            // Toggle button
                            TextButton(
                              onPressed: auth.loading
                                  ? null
                                  : () => setState(() => _signUp = !_signUp),
                              child: Text(
                                _signUp
                                    ? 'Already have an account? Sign in'
                                    : 'New to StyleStack? Create account',
                                textAlign: TextAlign.center,
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
      ),
    );
  }
}
