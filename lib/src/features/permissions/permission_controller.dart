import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/network/network_controller.dart';

class PermissionController extends ChangeNotifier {
  PermissionController({required NetworkController networkController})
      : _networkController = networkController;

  final NetworkController _networkController;

  bool _isInitialized = false;
  bool _notificationGranted = false;
  bool _fileGranted = false;

  bool get isInitialized => _isInitialized;
  bool get notificationGranted => _notificationGranted;
  bool get fileGranted => _fileGranted;
  bool get internetGranted => _networkController.isOnline;

  bool get hasMandatoryPermissions =>
      _notificationGranted && _fileGranted && internetGranted;

  Future<void> initialize() async {
    _networkController.addListener(_onNetworkChanged);
    await refreshStatuses();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> requestMandatoryPermissions() async {
    await _requestNotificationPermission();
    await _requestFilePermission();
    await _networkController.refreshStatus();
    await refreshStatuses();
  }

  Future<void> refreshStatuses() async {
    _notificationGranted = await _isNotificationGranted();
    _fileGranted = await _isFilePermissionGranted();
    notifyListeners();
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<void> _requestFilePermission() async {
    if (kIsWeb) {
      return;
    }

    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
      await Permission.photos.request();
      await Permission.videos.request();
      await Permission.audio.request();
      return;
    }

    if (Platform.isIOS) {
      await Permission.photos.request();
    }
  }

  Future<bool> _isNotificationGranted() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> _isFilePermissionGranted() async {
    if (kIsWeb) {
      return true;
    }

    if (Platform.isAndroid) {
      final storage = await Permission.storage.status;
      final manage = await Permission.manageExternalStorage.status;
      final photos = await Permission.photos.status;
      final videos = await Permission.videos.status;
      final audio = await Permission.audio.status;

      return storage.isGranted ||
          manage.isGranted ||
          photos.isGranted ||
          videos.isGranted ||
          audio.isGranted;
    }

    if (Platform.isIOS) {
      final photos = await Permission.photos.status;
      return photos.isGranted || photos.isLimited;
    }

    return true;
  }

  void _onNetworkChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _networkController.removeListener(_onNetworkChanged);
    super.dispose();
  }
}
