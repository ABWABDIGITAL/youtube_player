import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'youtube_player_method_channel.dart';

abstract class YoutubePlayerPlatform extends PlatformInterface {
  /// Constructs a YoutubePlayerPlatform.
  YoutubePlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static YoutubePlayerPlatform _instance = MethodChannelYoutubePlayer();

  /// The default instance of [YoutubePlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelYoutubePlayer].
  static YoutubePlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [YoutubePlayerPlatform] when
  /// they register themselves.
  static set instance(YoutubePlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
