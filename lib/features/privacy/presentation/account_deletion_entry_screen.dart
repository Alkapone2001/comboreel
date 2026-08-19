import 'package:flutter/material.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_user.dart';
import '../data/privacy_repository.dart';
import '../data/subscription_management_service.dart';
import 'privacy_center_screen.dart';

class AccountDeletionEntryScreen extends StatelessWidget {
  const AccountDeletionEntryScreen({
    super.key,
    required this.authRepository,
    required this.privacyRepository,
    required this.backendConfigured,
    this.subscriptionManagementService =
        const UnavailableSubscriptionManagementService(),
  });

  final AuthRepository authRepository;
  final PrivacyRepository privacyRepository;
  final bool backendConfigured;
  final SubscriptionManagementService subscriptionManagementService;

  @override
  Widget build(BuildContext context) {
    if (!backendConfigured) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Account deletion is unavailable because this deployment is not connected to ComboReel accounts.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return StreamBuilder<AuthUser?>(
      initialData: authRepository.currentUser,
      stream: authRepository.authStateChanges,
      builder: (context, snapshot) => snapshot.data == null
          ? _DeletionSignIn(repository: authRepository)
          : PrivacyCenterScreen(
              repository: privacyRepository,
              subscriptionManagementService: subscriptionManagementService,
            ),
    );
  }
}

class _DeletionSignIn extends StatefulWidget {
  const _DeletionSignIn({required this.repository});
  final AuthRepository repository;

  @override
  State<_DeletionSignIn> createState() => _DeletionSignInState();
}

class _DeletionSignInState extends State<_DeletionSignIn> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error
              .toString()
              .replaceFirst('AuthException(message: ', '')
              .split(', statusCode:')
              .first,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delete ComboReel account')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This secure page lets you review subscription warnings and permanently delete your ComboReel account and associated data.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => !(value?.contains('@') ?? false)
                        ? 'Enter a valid email.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onFieldSubmitted: (_) => _signIn(),
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'Use at least 8 characters.'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in securely'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'If you cannot access your account, contact ComboReel support after the public support address is configured.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
