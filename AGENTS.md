# Kar Upahar Repository Guidance

These instructions apply to the entire repository.

## Product constraints

- Treat Kar Upahar as an independent companion app, never as an official
  Government of Nepal product.
- Keep the official IRD portal as the source of truth.
- Do not bypass Cloudflare Turnstile, automate fabricated enrollments, or send
  test bills to the production IRD service.
- Keep digital-payment bills out of the IRD WebView; their coupon remains
  optional.

## Architecture and privacy

- Keep Flutter application code in `lib/`, Firebase backend code in `functions/`,
  and platform-specific configuration in `android/` and `ios/`.
- Preserve local-only startup when Firebase configuration is absent.
- Process OCR on-device. Do not upload or log bill images, raw OCR text, profile
  fields, or bill details.
- Keep OCR suggestions editable and leave uncertain fields blank.
- Preserve both Latin and Devanagari recognition and BS-to-AD conversion.
- Keep direct Firestore client access disabled; mobile cloud operations must use
  authenticated, App-Check-protected callable functions.

## Implementation conventions

- Read `README.md` and the relevant source before changing behavior.
- Reuse the existing `Copy` localization helper for all user-visible English and
  Nepali text.
- Maintain Android and future iOS compatibility. Native OCR changes must preserve
  the Android Devanagari dependency, the iOS Devanagari pod, and iOS 15.5.
- Do not regenerate platform folders with `flutter create`.
- Do not edit generated files or commit Firebase configuration, credentials,
  signing keys, build output, pods, or package caches.
- Commit `pubspec.lock` and `functions/package-lock.json` when their declared
  dependencies change.

## Verification

- Format only changed Dart files with `dart format`.
- Run `flutter test` and `flutter analyze` for Flutter changes.
- Run `flutter build apk --debug` when changing dependencies, Android
  configuration, permissions, OCR, camera handling, or native plugins.
- Run `npm test` from `functions/` for backend changes.
- Use fixtures and mocks for IRD behavior; never exercise production enrollment
  with fabricated data.
