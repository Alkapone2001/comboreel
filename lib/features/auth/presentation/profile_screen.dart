import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';
import '../../admin/data/admin_repository.dart';
import '../../admin/domain/admin_models.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../notifications/data/push_notification_service.dart';
import '../../privacy/data/privacy_repository.dart';
import '../../privacy/presentation/legal_document_screen.dart';
import '../../privacy/presentation/privacy_center_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.authRepository,
    required this.backendConfigured,
    required this.onOpenMyList,
    required this.adminRepository,
    required this.onOpenAdmin,
    this.analyticsRepository = const NoopAnalyticsRepository(),
    this.pushNotificationService = const UnavailablePushNotificationService(),
    this.privacyRepository = const UnavailablePrivacyRepository(),
  });

  final AuthRepository authRepository;
  final bool backendConfigured;
  final VoidCallback onOpenMyList;
  final AdminRepository adminRepository;
  final VoidCallback onOpenAdmin;
  final AnalyticsRepository analyticsRepository;
  final PushNotificationService pushNotificationService;
  final PrivacyRepository privacyRepository;

  @override
  Widget build(BuildContext context) {
    if (!backendConfigured) {
      return _BackendSetupView(onOpenMyList: onOpenMyList);
    }
    return StreamBuilder<AuthUser?>(
      initialData: authRepository.currentUser,
      stream: authRepository.authStateChanges,
      builder: (context, snapshot) => snapshot.data == null
          ? _AuthenticationView(repository: authRepository)
          : _SignedInProfile(
              user: snapshot.data!,
              repository: authRepository,
              onOpenMyList: onOpenMyList,
              adminRepository: adminRepository,
              onOpenAdmin: onOpenAdmin,
              analyticsRepository: analyticsRepository,
              pushNotificationService: pushNotificationService,
              privacyRepository: privacyRepository,
            ),
    );
  }
}

class _BackendSetupView extends StatelessWidget {
  const _BackendSetupView({required this.onOpenMyList});
  final VoidCallback onOpenMyList;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.coral, AppColors.magenta],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(Icons.person_rounded, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your ComboReel profile',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The interface is ready. Connect the Supabase staging project to enable accounts, watch history, favourites, coins, and subscriptions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Run with:\n--dart-define=SUPABASE_URL=...\n--dart-define=SUPABASE_PUBLISHABLE_KEY=...',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFFD9D9E0),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onOpenMyList,
                  icon: const Icon(Icons.bookmark_rounded),
                  label: const Text('Preview My List'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthenticationView extends StatefulWidget {
  const _AuthenticationView({required this.repository});
  final AuthRepository repository;

  @override
  State<_AuthenticationView> createState() => _AuthenticationViewState();
}

class _AuthenticationViewState extends State<_AuthenticationView> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _acceptedLegal = false;
  String? _error;

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_createAccount) {
        if (!_acceptedLegal) {
          setState(
            () => _error =
                'Accept the Privacy Policy and Terms to create an account.',
          );
          return;
        }
        await widget.repository.signUp(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _displayName.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created. Check your email if confirmation is enabled.',
              ),
            ),
          );
        }
      } else {
        await widget.repository.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error
        .toString()
        .replaceFirst('AuthException(message: ', '')
        .split(', statusCode:')
        .first;
    return message.isEmpty
        ? 'Authentication failed. Please try again.'
        : message;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _createAccount ? 'Join ComboReel' : 'Welcome back',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  _createAccount
                      ? 'Create an account to save stories and unlock episodes.'
                      : 'Sign in to continue your stories on any device.',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                if (_createAccount) ...[
                  TextFormField(
                    controller: _displayName,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter at least 2 characters.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => !(value?.contains('@') ?? false)
                      ? 'Enter a valid email.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                    ),
                  ),
                  validator: (value) => (value?.length ?? 0) < 8
                      ? 'Use at least 8 characters.'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: AppColors.coral)),
                ],
                if (_createAccount) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _acceptedLegal,
                    onChanged: _submitting
                        ? null
                        : (value) =>
                              setState(() => _acceptedLegal = value ?? false),
                    title: const Text(
                      'I accept the Privacy Policy and Terms of Use',
                    ),
                    subtitle: Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const LegalDocumentScreen(
                                document: LegalDocument.privacy,
                              ),
                            ),
                          ),
                          child: const Text('Privacy Policy'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const LegalDocumentScreen(
                                document: LegalDocument.terms,
                              ),
                            ),
                          ),
                          child: const Text('Terms of Use'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_createAccount ? 'Create account' : 'Sign in'),
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _createAccount = !_createAccount),
                  child: Text(
                    _createAccount
                        ? 'Already have an account? Sign in'
                        : 'New here? Create an account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SignedInProfile extends StatelessWidget {
  const _SignedInProfile({
    required this.user,
    required this.repository,
    required this.onOpenMyList,
    required this.adminRepository,
    required this.onOpenAdmin,
    required this.analyticsRepository,
    required this.pushNotificationService,
    required this.privacyRepository,
  });
  final AuthUser user;
  final AuthRepository repository;
  final VoidCallback onOpenMyList;
  final AdminRepository adminRepository;
  final VoidCallback onOpenAdmin;
  final AnalyticsRepository analyticsRepository;
  final PushNotificationService pushNotificationService;
  final PrivacyRepository privacyRepository;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
      children: [
        const CircleAvatar(
          radius: 38,
          child: Icon(Icons.person_rounded, size: 42),
        ),
        const SizedBox(height: 14),
        Text(
          user.email ?? 'ComboReel viewer',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 28),
        const _ProfileTile(icon: Icons.history_rounded, title: 'Watch history'),
        _ProfileTile(
          icon: Icons.favorite_outline_rounded,
          title: 'My favourites',
          onTap: onOpenMyList,
        ),
        const _ProfileTile(
          icon: Icons.workspace_premium_outlined,
          title: 'Premium membership',
        ),
        const _ProfileTile(
          icon: Icons.language_rounded,
          title: 'Language & subtitles',
        ),
        _AnalyticsConsentTile(repository: analyticsRepository),
        if (pushNotificationService.available)
          _PushConsentTile(service: pushNotificationService),
        _ProfileTile(
          icon: Icons.settings_outlined,
          title: 'Privacy & account',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  PrivacyCenterScreen(repository: privacyRepository),
            ),
          ),
        ),
        FutureBuilder<AdminRole>(
          future: adminRepository.currentRole(),
          builder: (context, snapshot) {
            if (snapshot.data != AdminRole.editor &&
                snapshot.data != AdminRole.admin) {
              return const SizedBox.shrink();
            }
            return _ProfileTile(
              icon: Icons.video_settings_outlined,
              title: 'Creator Studio',
              onTap: onOpenAdmin,
            );
          },
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: repository.signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    ),
  );
}

class _PushConsentTile extends StatefulWidget {
  const _PushConsentTile({required this.service});
  final PushNotificationService service;

  @override
  State<_PushConsentTile> createState() => _PushConsentTileState();
}

class _PushConsentTileState extends State<_PushConsentTile> {
  late Future<bool> _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.service.enabled();
  }

  Future<void> _change(bool value) async {
    setState(() => _saving = true);
    try {
      await widget.service.setEnabled(value);
      if (mounted) setState(() => _enabled = Future.value(value));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: FutureBuilder<bool>(
      future: _enabled,
      builder: (context, snapshot) => SwitchListTile(
        secondary: const Icon(Icons.notifications_active_outlined),
        title: const Text('Story notifications'),
        subtitle: const Text('New episodes and important account updates'),
        value: snapshot.data ?? false,
        onChanged: snapshot.hasData && !_saving ? _change : null,
      ),
    ),
  );
}

class _AnalyticsConsentTile extends StatefulWidget {
  const _AnalyticsConsentTile({required this.repository});
  final AnalyticsRepository repository;

  @override
  State<_AnalyticsConsentTile> createState() => _AnalyticsConsentTileState();
}

class _AnalyticsConsentTileState extends State<_AnalyticsConsentTile> {
  late Future<bool> _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.repository.consentEnabled();
  }

  Future<void> _change(bool value) async {
    setState(() => _saving = true);
    try {
      await widget.repository.setConsent(value);
      if (mounted) setState(() => _enabled = Future.value(value));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: FutureBuilder<bool>(
      future: _enabled,
      builder: (context, snapshot) => SwitchListTile(
        secondary: const Icon(Icons.analytics_outlined),
        title: const Text('Help improve ComboReel'),
        subtitle: const Text('Share privacy-safe viewing and purchase events'),
        value: snapshot.data ?? false,
        onChanged: snapshot.hasData && !_saving ? _change : null,
      ),
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.title, this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}
