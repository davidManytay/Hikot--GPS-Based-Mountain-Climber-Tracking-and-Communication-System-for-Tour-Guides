import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/hiker.dart';
import '../models/gps_packet.dart';
import '../models/trip.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (kIsWeb) throw UnsupportedError("Database not supported on Web");
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'hikot.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE hikers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        device_id TEXT UNIQUE NOT NULL,
        device_type INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE gps_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hiker_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        battery INTEGER,
        signal INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_time INTEGER,
        end_time INTEGER
      )
    ''');
  }

  // Hiker methods
  Future<int> insertHiker(Hiker hiker) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final List<Hiker> hikers = await getHikers();
      
      final newHiker = hiker.id == null ? hiker.copyWith(id: hikers.length + 1) : hiker;
      hikers.removeWhere((h) => h.deviceId == newHiker.deviceId);
      hikers.add(newHiker);
      
      final String encoded = jsonEncode(hikers.map((h) => h.toMap()).toList());
      await prefs.setString('web_hikers', encoded);
      return 1;
    }
    Database db = await database;
    return await db.insert('hikers', hiker.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Hiker>> getHikers() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? encoded = prefs.getString('web_hikers');
        if (encoded == null) return [];
        final List<dynamic> decoded = jsonDecode(encoded);
        return decoded.map((item) => Hiker.fromMap(Map<String, dynamic>.from(item))).toList();
      } catch (e) {
        debugPrint("Error loading web hikers: $e");
        return [];
      }
    }
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('hikers');
    return List.generate(maps.length, (i) => Hiker.fromMap(maps[i]));
  }

  Future<int> deleteHiker(int id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final List<Hiker> hikers = await getHikers();
      hikers.removeWhere((h) => h.id == id);
      final String encoded = jsonEncode(hikers.map((h) => h.toMap()).toList());
      await prefs.setString('web_hikers', encoded);
      return 1;
    }
    Database db = await database;
    return await db.delete('hikers', where: 'id = ?', whereArgs: [id]);
  }

  // GPS Log methods
  Future<int> logGPS(GpsPacket packet) async {
    Database db = await database;
    return await db.insert('gps_log', {
      'hiker_id': packet.hikerId,
      'lat': packet.lat,
      'lon': packet.lon,
      'timestamp': packet.timestamp,
      'battery': packet.batteryLevel,
      'signal': packet.signalStrength,
    });
  }

  Future<List<Map<String, dynamic>>> getGPSHistory(String hikerId) async {
    Database db = await database;
    return await db.query('gps_log', where: 'hiker_id = ?', whereArgs: [hikerId], orderBy: 'timestamp ASC');
  }

  // Trip methods
  Future<int> startTrip(String name) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final List<Trip> trips = await getTrips();
      
      final newTrip = Trip(
        id: trips.length + 1,
        name: name,
        startTime: DateTime.now(),
      );
      trips.add(newTrip);
      
      final String encoded = jsonEncode(trips.map((t) => t.toMap()).toList());
      await prefs.setString('web_trips', encoded);
      return 1;
    }
    Database db = await database;
    return await db.insert('trips', {
      'name': name,
      'start_time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> endTrip(int tripId) async {
    Database db = await database;
    return await db.update(
      'trips',
      {'end_time': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<List<Trip>> getTrips() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? encoded = prefs.getString('web_trips');
        if (encoded == null) return [];
        final List<dynamic> decoded = jsonDecode(encoded);
        return decoded.map((item) => Trip.fromMap(Map<String, dynamic>.from(item))).toList().reversed.toList();
      } catch (e) {
        debugPrint("Error loading web trips: $e");
        return [];
      }
    }
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('trips', orderBy: 'start_time DESC');
    return List.generate(maps.length, (i) => Trip.fromMap(maps[i]));
  }

  Future<Trip?> getCurrentTrip() async {
    if (kIsWeb) {
      final trips = await getTrips();
      final active = trips.where((t) => t.endTime == null).toList();
      return active.isEmpty ? null : active.last;
    }
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('trips', where: 'end_time IS NULL', limit: 1);
    if (maps.isEmpty) return null;
    return Trip.fromMap(maps.first);
  }
}
