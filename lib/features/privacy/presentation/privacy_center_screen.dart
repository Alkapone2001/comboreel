import 'package:flutter/material.dart';

import '../data/account_export_service.dart';
import '../data/privacy_repository.dart';
import '../data/subscription_management_service.dart';
import 'legal_document_screen.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({
    super.key,
    required this.repository,
    this.accountExportService = const SystemAccountExportService(),
    this.subscriptionManagementService =
        const UnavailableSubscriptionManagementService(),
  });
  final PrivacyRepository repository;
  final AccountExportService accountExportService;
  final SubscriptionManagementService subscriptionManagementService;
  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    try {
      final data = await widget.repository.exportData();
      await widget.accountExportService.export(
        AccountExportFile.fromJson(data),
        origin: origin,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your JSON export is ready to save or share.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      final preview = await widget.repository.deletionPreview();
      if (!mounted) return;
      final password = TextEditingController();
      var acknowledged = preview.activePlatforms.isEmpty;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Permanently delete account?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This permanently removes your profile, history, favourites, coins, and entitlements. It cannot be undone.',
                  ),
                  if (preview.activePlatforms.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Active subscription detected: ${preview.activePlatforms.join(', ')}. Account deletion does not cancel provider billing.',
                    ),
                    for (final platform in preview.activePlatforms)
                      if (widget.subscriptionManagementService.supports(
                        platform,
                      ))
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              try {
                                await widget.subscriptionManagementService
                                    .manage(platform);
                              } catch (error) {
                                if (context.mounted) _showError(error);
                              }
                            },
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(
                              widget.subscriptionManagementService.labelFor(
                                platform,
                              ),
                            ),
                          ),
                        ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: acknowledged,
                      onChanged: (value) =>
                          setDialogState(() => acknowledged = value ?? false),
                      title: const Text(
                        'I understand the subscription may continue.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep account'),
              ),
              FilledButton(
                onPressed: acknowledged
                    ? () => Navigator.pop(context, true)
                    : null,
                child: const Text('Delete permanently'),
              ),
            ],
          ),
        ),
      );
      if (confirmed == true) {
        await widget.repository.deleteAccount(
          password: password.text,
          acknowledgedSubscriptions: acknowledged,
        );
      }
      password.dispose();
      if (mounted && confirmed == true) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy Center')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Review how ComboReel uses data and exercise your account rights.',
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  const LegalDocumentScreen(document: LegalDocument.privacy),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Terms of Use'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  const LegalDocumentScreen(document: LegalDocument.terms),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Export my data'),
          subtitle: const Text('Save or share a portable JSON file'),
          onTap: _busy ? null : _export,
        ),
        const Divider(height: 32),
        ListTile(
          iconColor: Colors.redAccent,
          textColor: Colors.redAccent,
          leading: const Icon(Icons.delete_forever_outlined),
          title: const Text('Delete account'),
          subtitle: const Text('Permanent and irreversible'),
          onTap: _busy ? null : _delete,
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
  );
}
