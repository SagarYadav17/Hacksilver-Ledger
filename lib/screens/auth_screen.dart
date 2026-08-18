import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/security_utils.dart';
import '../utils/amount_colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _serverController.text = auth.serverUrl ?? '';
  }

  @override
  void dispose() {
    _serverController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    final connected = await auth.connect(_serverController.text.trim());
    if (!connected) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final success = _isSignUp
        ? await auth.signUp(email, password)
        : await auth.logIn(email, password);

    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Create account' : 'Log in')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: EdgeInsets.zero,
                color: colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_sync_outlined,
                        color: plannedColor(colorScheme),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Connect to your self-hosted PocketBase server. Your data stays scoped to your account.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _serverController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://pb.your-domain.com',
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  final result = SecurityUtils.validateServerUrl(value);
                  return result.isValid ? null : result.errorMessage;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final result = SecurityUtils.validateEmail(value);
                  return result.isValid ? null : result.errorMessage;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              if (auth.lastError != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.lastError!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isBusy ? null : () => _submit(auth),
                  child: auth.isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUp ? 'Create account' : 'Log in'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Log in'
                        : "Don't have an account? Sign up",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
