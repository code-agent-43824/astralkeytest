import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const duoRegionChannel = MethodChannel(
  'com.astralkey.astralkeytest/display_regions',
);

Future<void> sendDuoRegions(List<Rect> regions) {
  final data = [
    for (final region in regions)
      [region.left, region.top, region.right, region.bottom],
  ];
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        duoRegionChannel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('regionsChanged', data),
        ),
        (_) {},
      );
}
