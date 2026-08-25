import 'package:flutter/material.dart';

class ZoomableImageLabels {
  const ZoomableImageLabels({
    required this.title,
    required this.open,
    required this.zoomHint,
    required this.resetZoom,
  });

  final String title;
  final String open;
  final String zoomHint;
  final String resetZoom;
}

class ZoomableImage extends StatelessWidget {
  const ZoomableImage({
    super.key,
    required this.image,
    required this.labels,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
    this.showExpandIcon = true,
  });

  final ImageProvider<Object> image;
  final ZoomableImageLabels labels;
  final BoxFit fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;
  final bool showExpandIcon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: labels.open,
      child: Tooltip(
        message: labels.open,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => _FullScreenImagePage(
                image: image,
                labels: labels,
                errorBuilder: errorBuilder,
              ),
            ),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: image,
                  fit: fit,
                  errorBuilder: errorBuilder,
                ),
                if (showExpandIcon)
                  const Positioned(
                    top: 7,
                    right: 7,
                    child: _ExpandBadge(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenImagePage extends StatefulWidget {
  const _FullScreenImagePage({
    required this.image,
    required this.labels,
    this.errorBuilder,
  });

  final ImageProvider<Object> image;
  final ZoomableImageLabels labels;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<_FullScreenImagePage> createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<_FullScreenImagePage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late final AnimationController _zoomAnimationController;
  Matrix4Tween? _zoomTween;
  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(_applyAnimatedZoom);
  }

  @override
  void dispose() {
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _applyAnimatedZoom() {
    final tween = _zoomTween;
    if (tween == null) return;
    final progress = Curves.easeOutCubic.transform(
      _zoomAnimationController.value,
    );
    _transformationController.value = tween.lerp(progress);
  }

  void _animateTo(Matrix4 target) {
    _zoomAnimationController.stop();
    _zoomTween = Matrix4Tween(
      begin: _transformationController.value.clone(),
      end: target,
    );
    _zoomAnimationController.forward(from: 0);
  }

  void _handleDoubleTap() {
    if (_transformationController.value.getMaxScaleOnAxis() > 1.01) {
      _animateTo(Matrix4.identity());
      return;
    }

    const scale = 2.5;
    final target = Matrix4.identity()
      ..translateByDouble(
        -_doubleTapPosition.dx * (scale - 1),
        -_doubleTapPosition.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
    _animateTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.labels.title),
        actions: [
          IconButton(
            tooltip: widget.labels.resetZoom,
            onPressed: () => _animateTo(Matrix4.identity()),
            icon: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              key: const Key('full-screen-image-gesture'),
              behavior: HitTestBehavior.opaque,
              onDoubleTapDown: (details) {
                _doubleTapPosition = details.localPosition;
              },
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                key: const Key('full-screen-image-viewer'),
                transformationController: _transformationController,
                minScale: 1,
                maxScale: 6,
                onInteractionStart: (_) => _zoomAnimationController.stop(),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Image(
                    image: widget.image,
                    fit: BoxFit.contain,
                    errorBuilder: widget.errorBuilder,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xaa000000),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    child: Text(
                      widget.labels.zoomHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandBadge extends StatelessWidget {
  const _ExpandBadge();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xaa000000),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.fullscreen, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
