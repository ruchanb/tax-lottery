import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kar_upahar/src/widgets/zoomable_image.dart';

void main() {
  const labels = ZoomableImageLabels(
    title: 'Bill photo',
    open: 'Open bill photo',
    zoomHint: 'Pinch or double-tap to zoom',
    resetZoom: 'Reset zoom',
  );

  final onePixelImage = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '/x8AAusB9Wl2nWQAAAAASUVORK5CYII=',
    ),
  );

  testWidgets('opens a dedicated full-screen zoom viewer when tapped',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 120,
            child: ZoomableImage(image: onePixelImage, labels: labels),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ZoomableImage));
    await tester.pumpAndSettle();

    expect(find.text('Bill photo'), findsOneWidget);
    expect(find.byKey(const Key('full-screen-image-viewer')), findsOneWidget);
    expect(find.text('Pinch or double-tap to zoom'), findsOneWidget);
  });

  testWidgets('double-tap zooms and reset returns to the initial scale',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 120,
            child: ZoomableImage(image: onePixelImage, labels: labels),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ZoomableImage));
    await tester.pumpAndSettle();

    final viewerFinder = find.byKey(const Key('full-screen-image-viewer'));
    InteractiveViewer viewer = tester.widget(viewerFinder);
    final controller = viewer.transformationController!;

    final viewerCenter = tester.getCenter(viewerFinder);
    await tester.tapAt(viewerCenter);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(viewerCenter);
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(2.5, 0.01));

    await tester.tap(find.byTooltip('Reset zoom'));
    await tester.pumpAndSettle();
    viewer = tester.widget(viewerFinder);
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      closeTo(1, 0.01),
    );
  });
}
