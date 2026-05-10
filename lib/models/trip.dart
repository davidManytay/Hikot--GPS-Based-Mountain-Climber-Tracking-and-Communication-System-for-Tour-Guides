class Trip {
  final int? id;
  final String name;
  final DateTime? startTime;
  final DateTime? endTime;

  Trip({
    this.id,
    required this.name,
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_time': startTime?.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'],
      name: map['name'],
      startTime: map['start_time'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['start_time']) 
          : null,
      endTime: map['end_time'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['end_time']) 
          : null,
    );
  }
}
