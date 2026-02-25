// lib/features/account/widgets/account_action_tile.dart

import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

class AccountActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const AccountActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: AppTextStyles.bodyMedium),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
