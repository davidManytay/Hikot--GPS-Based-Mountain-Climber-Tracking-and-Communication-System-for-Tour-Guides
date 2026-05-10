import 'dart:async';
import 'package:collection/collection.dart';
import '../models/gps_packet.dart';

class PacketScheduler {
  final PriorityQueue<GpsPacket> _queue = PriorityQueue((a, b) => a.priority.compareTo(b.priority));
  final StreamController<GpsPacket> _outputController = StreamController<GpsPacket>.broadcast();
  Timer? _timer;

  Stream<GpsPacket> get outgoingPackets => _outputController.stream;

  void init() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_queue.isNotEmpty) {
        GpsPacket p = _queue.removeFirst();
        _outputController.add(p);
      }
    });
  }

  void enqueue(GpsPacket packet) {
    _queue.add(packet);
  }

  GpsPacket? dequeue() {
    return _queue.isNotEmpty ? _queue.removeFirst() : null;
  }

  void dispose() {
    _timer?.cancel();
    _outputController.close();
  }
}
