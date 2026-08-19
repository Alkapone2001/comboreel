class AccountProfile {
  const AccountProfile({
    required this.displayName,
    required this.email,
    required this.emailConfirmed,
    this.avatarUrl,
    this.pendingEmail,
  });

  final String displayName;
  final String? email;
  final bool emailConfirmed;
  final String? avatarUrl;
  final String? pendingEmail;
}
