import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:velofleet_driver/core/widgets/driver_widgets.dart';
import 'package:velofleet_driver/features/auth/presentation/auth_bloc.dart';

/// High-contrast driver login screen supporting email or phone + password.
class DriverLoginPage extends StatefulWidget {
  const DriverLoginPage({super.key});

  @override
  State<DriverLoginPage> createState() => _DriverLoginPageState();
}

class _DriverLoginPageState extends State<DriverLoginPage> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BlocBuilder<DriverAuthBloc, DriverAuthState>(
                builder: (context, state) {
                  final loading = state is DriverAuthLoading;
                  final error = state is DriverUnauthenticated ? state.errorMessage : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.directions_car_filled,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'VeloFleet Chauffeur',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in with your driver phone number or email.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(24),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(error, style: const TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _idCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phone or Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pwCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      LargeTouchButton(
                        label: 'Sign In',
                        icon: Icons.login,
                        isLoading: loading,
                        onPressed: () {
                          context.read<DriverAuthBloc>().add(
                            DriverLoginSubmitted(
                              identifier: _idCtrl.text,
                              password: _pwCtrl.text,
                            ),
                          );
                        },
                      ),
                    ],
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
