import 'dart:async';
import 'package:flutter/services.dart';
import 'youtube_player_platform_interface.dart';

class MethodChannelYouTubePlayer extends YouTubePlayerPlatform {
  final MethodChannel _channel = const MethodChannel('youtube_player');
  final EventChannel _stateChannel = const EventChannel('youtube_player/state');
  final EventChannel _positionChannel =
      const EventChannel('youtube_player/position');

  @override
  Future<void> initialize(String videoId, {String? apiKey}) async {
    await _channel.invokeMethod('initialize', {
      'videoId': videoId,
      'apiKey': apiKey,
    });
  }

  @override
  Future<void> loadVideo(String videoId) async {
    await _channel.invokeMethod('loadVideo', {'videoId': videoId});
  }

  @override
  Future<void> play() async {
    await _channel.invokeMethod('play');
  }

  @override
  Future<void> pause() async {
    await _channel.invokeMethod('pause');
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _channel.invokeMethod('seekTo', {'position': position.inMilliseconds});
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    await _channel.invokeMethod('setPlaybackRate', {'rate': rate});
  }

  @override
  Future<void> setQuality(String quality) async {
    await _channel.invokeMethod('setQuality', {'quality': quality});
  }

  @override
  Future<Duration> getCurrentPosition() async {
    final int? pos = await _channel.invokeMethod<int>('getCurrentPosition');
    return Duration(milliseconds: pos ?? 0);
  }

  @override
  Future<Duration> getDuration() async {
    final int? dur = await _channel.invokeMethod<int>('getDuration');
    return Duration(milliseconds: dur ?? 0);
  }

  @override
  Stream<PlaybackState> get onStateChanged {
    return _stateChannel.receiveBroadcastStream().map((dynamic event) {
      return _parsePlaybackState(event as String);
    });
  }

  @override
  Stream<Duration> get onPositionChanged {
    return _positionChannel.receiveBroadcastStream().map((dynamic event) {
      return Duration(milliseconds: event as int);
    });
  }

  PlaybackState _parsePlaybackState(String state) {
    switch (state) {
      case 'unstarted':
        return PlaybackState.unstarted;
      case 'ended':
        return PlaybackState.ended;
      case 'playing':
        return PlaybackState.playing;
      case 'paused':
        return PlaybackState.paused;
      case 'buffering':
        return PlaybackState.buffering;
      case 'queued':
        return PlaybackState.queued;
      default:
        return PlaybackState.unknown;
    }
  }
}
