import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get guideName => _prefs.getString('guide_name') ?? 'Unknown Guide';
  set guideName(String value) => _prefs.setString('guide_name', value);

  String get guideId => _prefs.getString('guide_id') ?? 'guide-001';
  set guideId(String value) => _prefs.setString('guide_id', value);

  bool get showHikerLabels => _prefs.getBool('show_hiker_labels') ?? true;
  set showHikerLabels(bool value) => _prefs.setBool('show_hiker_labels', value);

  int get heartbeatThresholdSeconds => _prefs.getInt('heartbeat_threshold_seconds') ?? 90;
  set heartbeatThresholdSeconds(int value) => _prefs.setInt('heartbeat_threshold_seconds', value);

  bool get isBackupGuide => _prefs.getBool('is_backup_guide') ?? false;
  set isBackupGuide(bool value) => _prefs.setBool('is_backup_guide', value);

  int get proximityThresholdMeters {
    try {
      return _prefs.getInt('proximity_threshold_meters') ?? 500;
    } catch (_) { return 500; }
  }
  set proximityThresholdMeters(int value) => _prefs.setInt('proximity_threshold_meters', value);

  int get immobilityThresholdMinutes {
    try {
      return _prefs.getInt('immobility_threshold_minutes') ?? 10;
    } catch (_) { return 10; }
  }
  set immobilityThresholdMinutes(int value) => _prefs.setInt('immobility_threshold_minutes', value);

  int get batteryWarningThreshold {
    try {
      return _prefs.getInt('battery_warning_threshold') ?? 20;
    } catch (_) { return 20; }
  }
  set batteryWarningThreshold(int value) => _prefs.setInt('battery_warning_threshold', value);

  Future<void> setGuideName(String name) async {
    await _prefs.setString('guide_name', name);
  }

  Future<void> setHeartbeatThreshold(int seconds) async {
    await _prefs.setInt('heartbeat_threshold_seconds', seconds);
  }
}
