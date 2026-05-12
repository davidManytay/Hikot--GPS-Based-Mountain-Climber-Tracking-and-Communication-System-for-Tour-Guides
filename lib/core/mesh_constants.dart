/// BLE mesh relay limits (flooding with deduplication per packet UUID).
abstract final class MeshConstants {
  /// Maximum hop count before a packet is dropped and no longer relayed.
  static const int maxHops = 12;
}
