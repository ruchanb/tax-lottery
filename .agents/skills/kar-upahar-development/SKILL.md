---
name: kar-upahar-development
description: Implement, debug, review, test, or document changes in the Kar Upahar Flutter tax-lottery companion app, including bill capture and OCR, bilingual UI, local SQLite records, IRD WebView enrollment, Firebase winner notifications, Android configuration, and future iOS compatibility.
---

# Kar Upahar Development

## Orient

1. Read `AGENTS.md` and `README.md`.
2. Inspect the relevant Flutter, platform, or Functions source before editing.
3. Preserve unrelated workspace changes and generated-file boundaries.

## Preserve product invariants

- Keep the app clearly independent from the Government of Nepal.
- Use the official IRD page as the enrollment source of truth.
- Keep digital bills local and out of the IRD WebView.
- Keep Firebase optional so the app starts in local-only mode.
- Keep profile data, bills, images, and OCR text on-device.
- Run OCR locally in Latin and Devanagari, convert valid BS dates to AD, and
  leave uncertain values blank and editable.
- Add every user-visible string in both English and Nepali through `Copy`.

## Implement safely

- Follow existing models, storage, and UI patterns before adding abstractions.
- Isolate changes to the IRD bridge because its DOM and response contract can
  change without notice.
- Preserve App Check and callable-function boundaries for cloud writes.
- Update both Android and iOS native configuration when a Flutter plugin requires
  platform-specific dependencies.
- Never submit fixture or fabricated data to the production IRD enrollment flow.

## Verify proportionally

- Run `dart format` on changed Dart files.
- Run `flutter test` and `flutter analyze`.
- Build a debug APK for dependency, native plugin, OCR, permission, or Android
  configuration changes.
- Run `npm test` inside `functions/` for backend changes.
- Report iOS build verification as pending when no macOS/Xcode environment is
  available.
