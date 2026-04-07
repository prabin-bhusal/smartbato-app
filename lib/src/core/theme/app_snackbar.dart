import 'package:flutter/material.dart';

/// Unified utility for showing consistently-styled snackbar notifications.
///
/// Usage:
///   AppSnackbar.success(context, 'Profile saved.');
///   AppSnackbar.error(context, 'Failed to load data.');
///   AppSnackbar.info(context, 'No changes were made.');
///   AppSnackbar.warning(context, 'Low coin balance.');
class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, _SnackType.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _SnackType.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _SnackType.info);

  static void warning(BuildContext context, String message) =>
      _show(context, message, _SnackType.warning);

  static void _show(BuildContext context, String message, _SnackType type) {
    final (borderColor, iconColor, bg, textColor, icon) = switch (type) {
      _SnackType.success => (
        const Color(0xFF22C55E),
        const Color(0xFF16A34A),
        const Color(0xFFF0FDF4),
        const Color(0xFF14532D),
        Icons.check_circle_rounded,
      ),
      _SnackType.error => (
        const Color(0xFFF87171),
        const Color(0xFFDC2626),
        const Color(0xFFFEF2F2),
        const Color(0xFF7F1D1D),
        Icons.error_rounded,
      ),
      _SnackType.warning => (
        const Color(0xFFFBBF24),
        const Color(0xFFD97706),
        const Color(0xFFFFFBEB),
        const Color(0xFF78350F),
        Icons.warning_amber_rounded,
      ),
      _SnackType.info => (
        const Color(0xFF60A5FA),
        const Color(0xFF1D4ED8),
        const Color(0xFFEFF6FF),
        const Color(0xFF1E3A8A),
        Icons.info_rounded,
      ),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          duration: const Duration(milliseconds: 3800),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor.withOpacity(0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.12),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
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

enum _SnackType { success, error, info, warning }
