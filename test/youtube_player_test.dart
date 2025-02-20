import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player/youtube_player.dart';
import 'package:youtube_player/youtube_player_platform_interface.dart';
import 'package:youtube_player/youtube_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockYoutubePlayerPlatform
    with MockPlatformInterfaceMixin
    implements YoutubePlayerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final YoutubePlayerPlatform initialPlatform = YoutubePlayerPlatform.instance;

  test('$MethodChannelYoutubePlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelYoutubePlayer>());
  });

  test('getPlatformVersion', () async {
    YoutubePlayer youtubePlayerPlugin = YoutubePlayer();
    MockYoutubePlayerPlatform fakePlatform = MockYoutubePlayerPlatform();
    YoutubePlayerPlatform.instance = fakePlatform;

    expect(await youtubePlayerPlugin.getPlatformVersion(), '42');
  });
}
