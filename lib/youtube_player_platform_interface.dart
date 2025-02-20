import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:youtube_player/youtube_player_method_channel.dart';

/// A common enum to represent playback state.
enum PlaybackState {
  unstarted,
  ended,
  playing,
  paused,
  buffering,
  queued,
  unknown,
}

/// The abstract interface for the YouTube player plugin.
abstract class YouTubePlayerPlatform extends PlatformInterface {
  YouTubePlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static YouTubePlayerPlatform _instance = MethodChannelYouTubePlayer();

  /// The default instance of [YouTubePlayerPlatform] to use.
  static YouTubePlayerPlatform get instance => _instance;

  /// Sets the default instance for testing or custom implementations.
  static set instance(YouTubePlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initializes the player with a video ID and an optional API key.
  Future<void> initialize(String videoId, {String? apiKey});

  /// Loads a new video by ID.
  Future<void> loadVideo(String videoId);

  /// Starts playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Seeks to a specific position in the video.
  Future<void> seekTo(Duration position);

  /// Sets the playback speed.
  Future<void> setPlaybackRate(double rate);

  /// Switches quality (e.g. "720p", "480p", etc.).
  Future<void> setQuality(String quality);

  /// Retrieves the current playback position.
  Future<Duration> getCurrentPosition();

  /// Retrieves the total duration of the video.
  Future<Duration> getDuration();

  /// A stream for playback state changes.
  Stream<PlaybackState> get onStateChanged;

  /// A stream for position updates.
  Stream<Duration> get onPositionChanged;
}
