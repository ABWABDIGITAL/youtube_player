// lib/youtube_player.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PlaybackState {
  unstarted,
  ended,
  playing,
  paused,
  buffering,
  queued,
  unknown,
}

class YouTubePlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final bool showControls;
  final Function(Duration)? onTimeUpdate;
  final Function(PlaybackState)? onStateChange;
  final Function()? onReady;
  final Function(String)? onError;
  final VoidCallback? onFullscreenTap;

  const YouTubePlayer({
    Key? key,
    required this.videoId,
    this.autoPlay = false,
    this.showControls = true,
    this.onTimeUpdate,
    this.onStateChange,
    this.onReady,
    this.onError,
    this.onFullscreenTap,
  }) : super(key: key);

  @override
  State<YouTubePlayer> createState() => _YouTubePlayerState();
}

class _YouTubePlayerState extends State<YouTubePlayer> {
  late MethodChannel _channel;
  final _controller = YouTubePlayerController();
  bool _isReady = false;
  PlaybackState _state = PlaybackState.unstarted;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    // Listen for local state changes and send commands to native side.
    _controller.addListener(() {
      // Sync play/pause state.
      if (_controller.value.isPlaying && _state != PlaybackState.playing) {
        _channel.invokeMethod('play');
      } else if (!_controller.value.isPlaying && _state == PlaybackState.playing) {
        _channel.invokeMethod('pause');
      }
      // Sync seek requests.
      if (_controller.value.position != _position) {
        _channel.invokeMethod('seekTo', {
          'position': _controller.value.position.inMilliseconds,
        });
      }
      // Playback rate changes.
      if (_controller.value.playbackRate != _controller.lastPlaybackRate) {
        _channel.invokeMethod('setPlaybackRate', {
          'rate': _controller.value.playbackRate,
        });
        _controller.lastPlaybackRate = _controller.value.playbackRate;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = {
      'videoId': widget.videoId,
      'autoPlay': widget.autoPlay,
    };

    Widget view;
    if (defaultTargetPlatform == TargetPlatform.android) {
      view = AndroidView(
        viewType: 'youtube_player_view',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      view = UiKitView(
        viewType: 'youtube_player_view',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return Stack(
      children: [
        view,
        if (widget.showControls)
          Positioned.fill(
            child: YouTubeCustomControls(
              controller: _controller,
              duration: _controller.value.duration,
              onFullscreenTap: widget.onFullscreenTap,
            ),
          ),
      ],
    );
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('youtube_player_$id');
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onReady':
        setState(() => _isReady = true);
        widget.onReady?.call();
        break;
      case 'onStateChange':
        final state = _parsePlaybackState(call.arguments as String);
        setState(() => _state = state);
        widget.onStateChange?.call(state);
        break;
      case 'onTimeChange':
        final position = Duration(milliseconds: call.arguments as int);
        setState(() => _position = position);
        widget.onTimeUpdate?.call(position);
        break;
      case 'onError':
        widget.onError?.call(call.arguments as String);
        break;
      default:
        throw MissingPluginException('Method ${call.method} not implemented');
    }
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

class YouTubePlayerController extends ValueNotifier<YouTubePlayerValue> {
  double lastPlaybackRate = 1.0; // For tracking changes in playback rate

  YouTubePlayerController() : super(YouTubePlayerValue());

  bool get isPlaying => value.isPlaying;
  Duration get position => value.position;
  double get playbackRate => value.playbackRate;

  void play() {
    value = value.copyWith(isPlaying: true);
  }

  void pause() {
    value = value.copyWith(isPlaying: false);
  }

  void seekTo(Duration position) {
    value = value.copyWith(position: position);
  }

  void setPlaybackRate(double rate) {
    value = value.copyWith(playbackRate: rate);
  }
}

class YouTubePlayerValue {
  final bool isPlaying;
  final Duration position;
  final double playbackRate;
  final String quality;
  final Duration duration;

  YouTubePlayerValue({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.playbackRate = 1.0,
    this.quality = 'auto',
    this.duration = Duration.zero,
  });

  YouTubePlayerValue copyWith({
    bool? isPlaying,
    Duration? position,
    double? playbackRate,
    String? quality,
    Duration? duration,
  }) {
    return YouTubePlayerValue(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      playbackRate: playbackRate ?? this.playbackRate,
      quality: quality ?? this.quality,
      duration: duration ?? this.duration,
    );
  }
}

// Enhanced custom controls with a magnificent UI.
class YouTubeCustomControls extends StatefulWidget {
  final YouTubePlayerController controller;
  final Duration duration;
  final VoidCallback? onFullscreenTap;

  const YouTubeCustomControls({
    Key? key,
    required this.controller,
    required this.duration,
    this.onFullscreenTap,
  }) : super(key: key);

  @override
  State<YouTubeCustomControls> createState() => _YouTubeCustomControlsState();
}

class _YouTubeCustomControlsState extends State<YouTubeCustomControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // Animation controller for fading controls in/out.
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Toggles the visibility of the controls.
  void _toggleVisibility() {
    setState(() {
      _visible = !_visible;
      if (_visible) {
        _fadeController.forward();
      } else {
        _fadeController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<YouTubePlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        return GestureDetector(
          onTap: _toggleVisibility,
          onDoubleTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 2) {
              widget.controller
                  .seekTo(value.position - const Duration(seconds: 10));
            } else {
              widget.controller
                  .seekTo(value.position + const Duration(seconds: 10));
            }
          },
          child: FadeTransition(
            opacity: _fadeController,
            child: Stack(
              children: [
                // A full-screen gradient background for the controls.
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.8)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Positioned controls at the bottom.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Custom progress bar with enhanced slider design.
                        SliderTheme(
                          data: SliderThemeData(
                            thumbColor: Colors.amberAccent,
                            activeTrackColor: Colors.amberAccent,
                            inactiveTrackColor: Colors.white70,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8),
                            overlayColor: Colors.amber.withOpacity(0.3),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: value.position.inMilliseconds.toDouble(),
                            max: widget.duration.inMilliseconds.toDouble(),
                            onChanged: (newPos) {
                              widget.controller.seekTo(Duration(
                                  milliseconds: newPos.toInt()));
                            },
                          ),
                        ),
                        // Row of controls.
                        Row(
                          children: [
                            // Play/Pause Button with a nice icon.
                            IconButton(
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                size: 32,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (value.isPlaying) {
                                  widget.controller.pause();
                                } else {
                                  widget.controller.play();
                                }
                              },
                            ),
                            // Time display with custom style.
                            Text(
                              '${_formatDuration(value.position)} / ${_formatDuration(widget.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            // Playback speed selector.
                            PopupMenuButton<double>(
                              icon: const Icon(Icons.speed, color: Colors.white),
                              onSelected: widget.controller.setPlaybackRate,
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 0.25, child: Text('0.25x')),
                                const PopupMenuItem(
                                    value: 0.5, child: Text('0.5x')),
                                const PopupMenuItem(
                                    value: 1.0, child: Text('1.0x')),
                                const PopupMenuItem(
                                    value: 1.5, child: Text('1.5x')),
                                const PopupMenuItem(
                                    value: 2.0, child: Text('2.0x')),
                                const PopupMenuItem(
                                    value: 2.5, child: Text('2.5x')),
                                const PopupMenuItem(
                                    value: 3.0, child: Text('3.0x')),
                              ],
                            ),
                            // Fullscreen toggle button.
                            IconButton(
                              icon: const Icon(Icons.fullscreen,
                                  color: Colors.white),
                              onPressed: widget.onFullscreenTap,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
