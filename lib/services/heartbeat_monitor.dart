import 'dart:async';
import '../models/hiker.dart';
import '../services/settings_service.dart';

class HeartbeatMonitor {
  final Map<String, DateTime> _lastSeen = {};
  final StreamController<String> _lostSignalController = StreamController<String>.broadcast();
  final SettingsService _settings = SettingsService();
  Timer? _timer;

  Stream<String> get lostSignalStream => _lostSignalController.stream;

  void updateLastSeen(String hikerId) {
    _lastSeen[hikerId] = DateTime.now();
  }

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final now = DateTime.now();
      final threshold = _settings.heartbeatThresholdSeconds;
      
      _lastSeen.forEach((id, lastTime) {
        if (now.difference(lastTime).inSeconds > threshold) {
          _lostSignalController.add(id);
        }
      });
    });
  }

  HikerStatus getStatus(String hikerId) {
    if (!_lastSeen.containsKey(hikerId)) return HikerStatus.noSignal;
    
    final diff = DateTime.now().difference(_lastSeen[hikerId]!).inSeconds;
    if (diff > 300) return HikerStatus.missing;
    if (diff > 90) return HikerStatus.noSignal;
    if (diff > 60) return HikerStatus.warning;
    return HikerStatus.active;
  }

  void stop() {
    _timer?.cancel();
    _lostSignalController.close();
  }
}
