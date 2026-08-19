import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/account_profile_repository.dart';
import '../domain/account_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.repository});

  final AccountProfileRepository repository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _displayName = TextEditingController();
  late Future<AccountProfile> _profile;
  bool _savingName = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.repository.currentProfile();
  }

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final value = _displayName.text.trim();
    if (value.isEmpty || value.length > 60) {
      _message('Display name must be between 1 and 60 characters.');
      return;
    }
    setState(() => _savingName = true);
    try {
      final profile = await widget.repository.updateDisplayName(value);
      if (mounted) {
        setState(() => _profile = Future.value(profile));
        _message('Profile updated.');
      }
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changeEmail() async {
    var email = '';
    final submitted = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change email'),
        content: TextField(
          onChanged: (value) => email = value.trim(),
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'New email address',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, email),
            child: const Text('Send confirmation'),
          ),
        ],
      ),
    );
    if (submitted == null || !mounted) return;
    if (!submitted.contains('@')) {
      _message('Enter a valid email address.');
      return;
    }
    try {
      await widget.repository.requestEmailChange(submitted);
      if (mounted) {
        _message(
          'Confirmation sent. Your email changes only after verification.',
        );
        setState(() => _profile = widget.repository.currentProfile());
      }
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    }
  }

  Future<void> _resendConfirmation() async {
    try {
      final email = await widget.repository.currentProfile().then(
        (profile) => profile.email,
      );
      if (email == null) throw StateError('This account has no email address.');
      await widget.repository.resendEmailConfirmation(email);
      if (mounted) _message('Confirmation email sent.');
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    }
  }

  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile details')),
    body: FutureBuilder<AccountProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              onPressed: () =>
                  setState(() => _profile = widget.repository.currentProfile()),
              child: const Text('Try again'),
            ),
          );
        }
        final profile = snapshot.requireData;
        if (_displayName.text.isEmpty) {
          _displayName.text = profile.displayName;
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const CircleAvatar(
              radius: 42,
              child: Icon(Icons.person_rounded, size: 46),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _displayName,
              maxLength: 60,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveName(),
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _savingName ? null : _saveName,
              child: _savingName
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save display name'),
            ),
            const SizedBox(height: 28),
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email address',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(profile.email ?? 'No email address'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          profile.emailConfirmed
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          size: 18,
                          color: profile.emailConfirmed
                              ? Colors.greenAccent
                              : AppColors.coral,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          profile.emailConfirmed
                              ? 'Verified'
                              : 'Verification required',
                        ),
                      ],
                    ),
                    if (profile.pendingEmail != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Pending: ${profile.pendingEmail}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _changeEmail,
                          child: const Text('Change email'),
                        ),
                        if (!profile.emailConfirmed)
                          TextButton(
                            onPressed: _resendConfirmation,
                            child: const Text('Resend verification'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

String _friendlyError(Object error) => error
    .toString()
    .replaceFirst('AuthException(message: ', '')
    .split(', statusCode:')
    .first
    .replaceFirst('Bad state: ', '');
