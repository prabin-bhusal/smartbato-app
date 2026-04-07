import 'package:flutter/material.dart';

import 'permission_controller.dart';

class MandatoryPermissionsScreen extends StatelessWidget {
  const MandatoryPermissionsScreen({
    super.key,
    required this.permissionController,
  });

  final PermissionController permissionController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: permissionController,
                builder: (context, _) {
                  final allGranted = permissionController.hasMandatoryPermissions;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        size: 56,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Mandatory Permissions',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'File access, notifications, and active internet are required to continue using SmartBato.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                      _PermissionTile(
                        icon: Icons.folder_open_rounded,
                        title: 'File Access',
                        description: 'Required for report and attachment downloads.',
                        granted: permissionController.fileGranted,
                      ),
                      const SizedBox(height: 10),
                      _PermissionTile(
                        icon: Icons.notifications_active_rounded,
                        title: 'Notifications',
                        description: 'Required for important announcements and updates.',
                        granted: permissionController.notificationGranted,
                      ),
                      const SizedBox(height: 10),
                      _PermissionTile(
                        icon: Icons.wifi_rounded,
                        title: 'Internet Connection',
                        description: 'Required to load live data from SmartBato servers.',
                        granted: permissionController.internetGranted,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: allGranted
                            ? null
                            : () => permissionController.requestMandatoryPermissions(),
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text(allGranted ? 'All Permissions Granted' : 'Grant Mandatory Permissions'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => permissionController.openSystemSettings(),
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text('Open System Settings'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => permissionController.refreshStatuses(),
                        child: const Text('Refresh Status'),
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

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final accent = granted ? const Color(0xFF16A34A) : const Color(0xFFB91C1C);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.14),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: accent,
          ),
        ],
      ),
    );
  }
}
