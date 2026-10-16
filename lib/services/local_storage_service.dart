import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/appointment.dart';

class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();

  static const String _usersKey = 'medbook_users_v1';
  static const String _appointmentsKey = 'medbook_appointments_v1';
  static const String _sessionKey = 'medbook_session_v1';

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<List<Map<String, dynamic>>> _readRecords(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeRecords(
    String key,
    List<Map<String, dynamic>> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(records));
  }

  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readRecords(_usersKey);

    final exists = users.any(
      (user) =>
          (user['email']?.toString() ?? '').toLowerCase() == normalizedEmail,
    );

    if (exists) return null;

    final user = AppUser(
      name: name.trim(),
      email: normalizedEmail,
      passwordHash: _hashPassword(password),
    );

    users.add(user.toMap());
    await _writeRecords(_usersKey, users);
    await setSession(user.email);

    return user;
  }

  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readRecords(_usersKey);
    final passwordHash = _hashPassword(password);

    for (final record in users) {
      final user = AppUser.fromMap(record);

      if (user.email.toLowerCase() == normalizedEmail &&
          user.passwordHash == passwordHash) {
        await setSession(user.email);
        return user;
      }
    }

    return null;
  }

  Future<AppUser?> getUser(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readRecords(_usersKey);

    for (final record in users) {
      final user = AppUser.fromMap(record);

      if (user.email.toLowerCase() == normalizedEmail) {
        return user;
      }
    }

    return null;
  }

  Future<String?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  Future<void> setSession(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, email.trim().toLowerCase());
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<List<Appointment>> getAppointments(String email) async {
    final records = await _readRecords(_appointmentsKey);
    final normalizedEmail = email.trim().toLowerCase();

    return records
        .map((record) => Appointment.fromMap(record))
        .where(
          (appointment) =>
              appointment.accountEmail.toLowerCase() == normalizedEmail,
        )
        .toList()
      ..sort(
        (a, b) => a.appointmentDate.compareTo(b.appointmentDate),
      );
  }

  Future<int> addAppointment(Appointment appointment) async {
    final records = await _readRecords(_appointmentsKey);

    final exists = records.any(
      (record) => record['id'].toString() == appointment.id.toString(),
    );

    if (exists) {
      throw StateError('This appointment ID already exists.');
    }

    records.add(appointment.toMap());
    await _writeRecords(_appointmentsKey, records);

    return appointment.id;
  }

  Future<bool> updateAppointment(Appointment appointment) async {
    final records = await _readRecords(_appointmentsKey);

    final index = records.indexWhere(
      (record) => record['id'].toString() == appointment.id.toString(),
    );

    if (index == -1) return false;

    records[index] = appointment.toMap();
    await _writeRecords(_appointmentsKey, records);

    return true;
  }

  Future<bool> deleteAppointment(int id, String email) async {
    final records = await _readRecords(_appointmentsKey);
    final originalLength = records.length;
    final normalizedEmail = email.trim().toLowerCase();

    records.removeWhere(
      (record) =>
          record['id'].toString() == id.toString() &&
          (record['accountEmail']?.toString() ?? '').toLowerCase() ==
              normalizedEmail,
    );

    if (records.length == originalLength) return false;

    await _writeRecords(_appointmentsKey, records);
    return true;
  }
}
