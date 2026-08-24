import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models.dart';

class LocalStore {
  late Database _db;

  Future<void> open() async {
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'kar_upahar.db'),
      version: 2,
      onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE profile (id INTEGER PRIMARY KEY CHECK (id = 1), name TEXT NOT NULL, mobile TEXT NOT NULL, address TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT, bill_number TEXT NOT NULL, seller_pan TEXT NOT NULL, bill_date TEXT NOT NULL, amount REAL NOT NULL, payment_method TEXT NOT NULL, image_path TEXT NOT NULL, status TEXT NOT NULL, coupon TEXT, server_message TEXT, created_at TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
              'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        }
      },
    );
    await _recoverMisclassifiedEnrollments();
  }

  Future<void> _recoverMisclassifiedEnrollments() async {
    final rows = await _db.query(
      'bills',
      columns: ['id', 'server_message'],
      where: 'status = ? AND coupon IS NULL AND server_message IS NOT NULL',
      whereArgs: [EnrollmentStatus.rejected.name],
    );
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row['server_message']! as String);
        final coupon = _findCoupon(decoded);
        if (coupon == null) continue;
        await _db.update(
          'bills',
          {
            'status': EnrollmentStatus.submitted.name,
            'coupon': coupon,
            'server_message': null,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (_) {
        // Genuine rejection messages are not successful enrollment payloads.
      }
    }
  }

  String? _findCoupon(Object? value) {
    const keys = [
      'couponNumber',
      'prize_coupon_number',
      'coupon',
      'coupon_number',
      'coupon_no',
      'ticket_number',
    ];
    if (value is Map) {
      for (final key in keys) {
        final coupon = value[key];
        if (coupon != null && coupon.toString().trim().isNotEmpty) {
          return coupon.toString().trim();
        }
      }
      for (final child in value.values) {
        final coupon = _findCoupon(child);
        if (coupon != null) return coupon;
      }
    } else if (value is List) {
      for (final child in value) {
        final coupon = _findCoupon(child);
        if (coupon != null) return coupon;
      }
    }
    return null;
  }

  Future<UserProfile?> getProfile() async {
    final rows = await _db.query('profile', where: 'id = 1');
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }

  Future<AppLanguage> getLanguage() async {
    final rows = await _db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['language'],
    );
    if (rows.isEmpty) return AppLanguage.ne;
    return AppLanguage.values.byName(rows.first['value']! as String);
  }

  Future<void> saveLanguage(AppLanguage language) => _db.insert(
        'settings',
        {'key': 'language', 'value': language.name},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> saveProfile(UserProfile profile) => _db.insert(
        'profile',
        {'id': 1, ...profile.toMap()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<BillEntry>> getBills() async =>
      (await _db.query('bills', orderBy: 'created_at DESC'))
          .map(BillEntry.fromMap)
          .toList(growable: false);

  Future<BillEntry> saveBill(BillEntry bill) async {
    final map = bill.toMap()..remove('id');
    final id = await _db.insert('bills', map);
    return bill.copyWith(id: id);
  }

  Future<void> updateBill(BillEntry bill) async {
    final map = bill.toMap()..remove('id');
    await _db.update('bills', map, where: 'id = ?', whereArgs: [bill.id]);
  }

  Future<void> deleteBill(BillEntry bill) async {
    await _db.delete('bills', where: 'id = ?', whereArgs: [bill.id]);
    final image = File(bill.imagePath);
    if (await image.exists()) await image.delete();
  }

  Future<String> retainPhoto(String temporaryPath) async {
    final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'bills'));
    await dir.create(recursive: true);
    final extension = p.extension(temporaryPath).isEmpty
        ? '.jpg'
        : p.extension(temporaryPath);
    final destination =
        p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}$extension');
    return (await File(temporaryPath).copy(destination)).path;
  }
}
