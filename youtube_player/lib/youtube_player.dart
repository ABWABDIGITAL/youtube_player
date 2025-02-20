
import 'youtube_player_platform_interface.dart';

class YoutubePlayer {
  Future<String?> getPlatformVersion() {
    return YoutubePlayerPlatform.instance.getPlatformVersion();
  }
}
