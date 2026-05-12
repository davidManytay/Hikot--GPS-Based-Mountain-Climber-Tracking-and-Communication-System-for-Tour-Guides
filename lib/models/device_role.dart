/// Tour guide hub vs climber node (objectives: role-based architecture).
enum HikotDeviceRole {
  guideHub,
  climberNode;

  String get storageValue => switch (this) {
        HikotDeviceRole.guideHub => 'guide_hub',
        HikotDeviceRole.climberNode => 'climber_node',
      };

  static HikotDeviceRole fromStorage(String? raw) {
    switch (raw) {
      case 'climber_node':
        return HikotDeviceRole.climberNode;
      default:
        return HikotDeviceRole.guideHub;
    }
  }
}
