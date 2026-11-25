import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/brand_theme.dart';
import 'auth_bloc.dart';

/// Staff Windows Desktop sign-in screen.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _totp = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _totp.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthLoginSubmitted(
        identifier: _identifier.text,
        password: _password.text,
        totpCode: _totp.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<BrandTokens>() ?? BrandTokens.light;
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 420,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final busy = state is AuthSubmitting;
                  final failure = state is AuthUnauthenticated ? state.failure : null;
                  return Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_taxi, color: t.primary700, size: 28),
                            const SizedBox(width: 10),
                            const Text(
                              'VeloFleet Operations',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in with an authorized staff account.',
                          style: TextStyle(color: t.textSecondary),
                        ),
                        const SizedBox(height: 18),
                        if (failure != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: t.errorBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(failure.message, style: TextStyle(color: t.errorFg)),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _identifier,
                          decoration: const InputDecoration(labelText: 'Staff Email or Phone'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password'),
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _totp,
                          decoration: const InputDecoration(labelText: 'TOTP Code (if MFA enabled)'),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: busy ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(busy ? 'Signing In...' : 'Sign In'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
