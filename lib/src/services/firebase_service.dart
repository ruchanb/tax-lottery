import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../domain/validation.dart';

class FirebaseService {
  FirebaseService({required this.enabled});

  final bool enabled;
  String? _token;

  Future<void> initialize() async {
    if (!enabled) return;
    await FirebaseAuth.instance.signInAnonymously();
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    _token = await messaging.getToken();
    await _registerInstallation();
    messaging.onTokenRefresh.listen((token) async {
      _token = token;
      await _registerInstallation();
    });
    final config = FirebaseRemoteConfig.instance;
    await config.setDefaults(const {
      'ird_submission_enabled': true,
      'ird_external_browser_fallback': false,
      'ird_portal_url': 'https://prize.ird.gov.np/',
    });
    await config.fetchAndActivate();
  }

  bool get submissionEnabled =>
      !enabled ||
      FirebaseRemoteConfig.instance.getBool('ird_submission_enabled');

  String get portalUrl => enabled
      ? FirebaseRemoteConfig.instance.getString('ird_portal_url')
      : 'https://prize.ird.gov.np/';

  bool get externalBrowserFallback =>
      enabled &&
      FirebaseRemoteConfig.instance.getBool('ird_external_browser_fallback');

  Future<void> _registerInstallation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _token == null) return;
    await FirebaseFunctions.instance
        .httpsCallable('registerInstallation')
        .call({
      'fcmToken': _token,
      'platform': 'mobile',
      'locale': 'ne-NP',
    });
  }

  Future<void> registerCoupon(String coupon, DateTime drawDate) async {
    if (!enabled) return;
    final normalized = normalizeCoupon(coupon);
    final hash = sha256.convert(utf8.encode(normalized)).toString();
    await FirebaseFunctions.instance.httpsCallable('registerCoupon').call({
      'couponHash': hash,
      'drawPeriod': drawDate.toIso8601String().substring(0, 10),
    });
  }

  Future<List<Map<String, String>>> getWinners() async {
    if (!enabled) return const [];
    final result =
        await FirebaseFunctions.instance.httpsCallable('getWinners').call();
    final payload = Map<String, dynamic>.from(result.data as Map);
    final rows = payload['winners'] as List? ?? const [];
    return rows.map((row) {
      final winner = Map<String, dynamic>.from(row as Map);
      return winner.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    }).toList(growable: false);
  }
}
