import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DuoDisplayLayout extends StatefulWidget {
  const DuoDisplayLayout({super.key, required this.child});

  final Widget child;

  @override
  State<DuoDisplayLayout> createState() => _DuoDisplayLayoutState();
}

class _DuoDisplayLayoutState extends State<DuoDisplayLayout> {
  static const _channel = MethodChannel(
    'com.astralkey.astralkeytest/display_regions',
  );

  List<Rect> _divisions = const [];

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_onRegionUpdate);
    unawaited(_requestRegions());
  }

  Future<void> _requestRegions() async {
    try {
      await _channel.invokeMethod<void>('requestRegions');
    } on MissingPluginException {
      // The scene registers the channel as soon as UIKit provides its view.
    }
  }

  Future<void> _onRegionUpdate(MethodCall call) async {
    if (call.method != 'regionsChanged') {
      throw MissingPluginException(call.method);
    }
    final coordinates = call.arguments;
    if (!mounted || coordinates is! List) return;

    final divisions = [
      for (final frame in coordinates)
        if (frame case [num left, num top, num right, num bottom])
          Rect.fromLTRB(
            left.toDouble(),
            top.toDouble(),
            right.toDouble(),
            bottom.toDouble(),
          ),
    ];
    if (!listEquals(_divisions, divisions)) {
      setState(() => _divisions = divisions);
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Rect? _dividerInWindow(Rect frame, Rect window) {
    if (!frame.isFinite ||
        frame.width < 0 ||
        frame.height < 0 ||
        frame.longestSide == 0) {
      return null;
    }
    if (frame.height >= frame.width &&
        frame.left > window.left &&
        frame.right < window.right &&
        frame.top < window.bottom &&
        frame.bottom > window.top) {
      return Rect.fromLTRB(frame.left, window.top, frame.right, window.bottom);
    }
    if (frame.width > frame.height &&
        frame.top > window.top &&
        frame.bottom < window.bottom &&
        frame.left < window.right &&
        frame.right > window.left) {
      return Rect.fromLTRB(window.left, frame.top, window.right, frame.bottom);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final window = Offset.zero & media.size;
    final layout = media.copyWith(
      displayFeatures: [
        ...media.displayFeatures,
        for (final division in _divisions)
          if (_dividerInWindow(division, window) case final Rect divider)
            DisplayFeature(
              bounds: divider,
              type: DisplayFeatureType.hinge,
              state: DisplayFeatureState.postureHalfOpened,
            ),
      ],
    );
    final safeWindow = media.padding.deflateRect(window);
    double usableArea(Rect pane) {
      final available = pane.intersect(safeWindow);
      return available.isEmpty ? 0 : available.width * available.height;
    }

    final largestPane = DisplayFeatureSubScreen.subScreensInBounds(
      window,
      DisplayFeatureSubScreen.avoidBounds(layout),
    ).reduce((a, b) => usableArea(a) >= usableArea(b) ? a : b);

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: MediaQuery(
        data: layout,
        child: DisplayFeatureSubScreen(
          anchorPoint: largestPane.center,
          child: widget.child,
        ),
      ),
    );
  }
}
