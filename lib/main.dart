import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/local_store.dart';
import 'src/domain/validation.dart';
import 'src/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    firebaseReady = true;
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Local development remains usable before platform Firebase files are added.
  }

  final store = LocalStore();
  await store.open();
  final firebase = FirebaseService(enabled: firebaseReady);
  if (firebaseReady) {
    unawaited(_initializeFirebaseAndSync(firebase, store));
  }

  runApp(KarUpaharApp(store: store, firebase: firebase));
}

Future<void> _initializeFirebaseAndSync(
    FirebaseService firebase, LocalStore store) async {
  await firebase.initialize();
  for (final bill in await store.getBills()) {
    if (bill.isActive && bill.coupon != null) {
      await firebase.registerCoupon(bill.coupon!, nextDrawDate(bill.billDate));
    }
  }
}
