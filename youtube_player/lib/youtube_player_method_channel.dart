import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'youtube_player_platform_interface.dart';

/// An implementation of [YoutubePlayerPlatform] that uses method channels.
class MethodChannelYoutubePlayer extends YoutubePlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('youtube_player');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
