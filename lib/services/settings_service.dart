import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_role.dart';

class SettingsService with ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get guideName => _prefs.getString('guide_name') ?? 'Unknown Guide';
  set guideName(String value) {
    _prefs.setString('guide_name', value);
    notifyListeners();
  }

  String get guideId => _prefs.getString('guide_id') ?? 'guide-001';
  set guideId(String value) {
    _prefs.setString('guide_id', value);
    notifyListeners();
  }

  bool get showHikerLabels => _prefs.getBool('show_hiker_labels') ?? true;
  set showHikerLabels(bool value) {
    _prefs.setBool('show_hiker_labels', value);
    notifyListeners();
  }

  bool get isDarkMode => _prefs.getBool('is_dark_mode') ?? true;
  set isDarkMode(bool value) {
    _prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  int get heartbeatThresholdSeconds => _prefs.getInt('heartbeat_threshold_seconds') ?? 90;
  set heartbeatThresholdSeconds(int value) {
    _prefs.setInt('heartbeat_threshold_seconds', value);
    notifyListeners();
  }

  bool get isBackupGuide => _prefs.getBool('is_backup_guide') ?? false;
  set isBackupGuide(bool value) {
    _prefs.setBool('is_backup_guide', value);
    notifyListeners();
  }

  HikotDeviceRole get deviceRole =>
      HikotDeviceRole.fromStorage(_prefs.getString('device_role'));

  Future<void> setDeviceRole(HikotDeviceRole role) async {
    await _prefs.setString('device_role', role.storageValue);
    notifyListeners();
  }

  /// BLE / mesh identity for this handset when in climber (node) mode.
  String get climberNodeId =>
      _prefs.getString('climber_node_id') ?? 'climber-node-local';

  set climberNodeId(String value) {
    _prefs.setString('climber_node_id', value);
    notifyListeners();
  }

  /// When true, climber handset periodically broadcasts GPS on the BLE mesh for the guide.
  bool get climberBroadcastGpsOnMesh => _prefs.getBool('climber_broadcast_gps_mesh') ?? true;
  set climberBroadcastGpsOnMesh(bool value) {
    _prefs.setBool('climber_broadcast_gps_mesh', value);
    notifyListeners();
  }

  int get proximityThresholdMeters {
    try {
      return _prefs.getInt('proximity_threshold_meters') ?? 500;
    } catch (_) {
      return 500;
    }
  }

  set proximityThresholdMeters(int value) {
    _prefs.setInt('proximity_threshold_meters', value);
    notifyListeners();
  }

  int get immobilityThresholdMinutes {
    try {
      return _prefs.getInt('immobility_threshold_minutes') ?? 10;
    } catch (_) { return 10; }
  }
  set immobilityThresholdMinutes(int value) {
    _prefs.setInt('immobility_threshold_minutes', value);
    notifyListeners();
  }

  int get batteryWarningThreshold {
    try {
      return _prefs.getInt('battery_warning_threshold') ?? 20;
    } catch (_) { return 20; }
  }
  set batteryWarningThreshold(int value) {
    _prefs.setInt('battery_warning_threshold', value);
    notifyListeners();
  }

  Future<void> setGuideName(String name) async {
    await _prefs.setString('guide_name', name);
    notifyListeners();
  }

  Future<void> setHeartbeatThreshold(int seconds) async {
    await _prefs.setInt('heartbeat_threshold_seconds', seconds);
    notifyListeners();
  }
}
