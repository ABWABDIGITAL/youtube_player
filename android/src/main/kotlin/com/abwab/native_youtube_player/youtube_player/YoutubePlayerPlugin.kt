package com.abwab.native_youtube_player.youtube_player

import android.content.Context
import android.util.Log
import com.google.android.youtube.player.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

private const val TAG = "NativeYouTubePlayer"

// Main plugin class registering the view factory.
class YouTubePlayerPlugin : FlutterPlugin {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "youtube_player")
        binding.platformViewRegistry.registerViewFactory(
            "youtube_player_view",
            YouTubePlayerFactory(binding.binaryMessenger)
        )
        Log.i(TAG, "YouTubePlayerPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        Log.i(TAG, "YouTubePlayerPlugin detached from engine")
    }
}

// Factory that creates instances of the native YouTube player view.
class YouTubePlayerFactory(private val messenger: io.flutter.plugin.common.BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<String, Any>
        return NativeYouTubePlayer(context, viewId, params, messenger)
    }
}

// Our main PlatformView wrapping the YouTubePlayerView.
class NativeYouTubePlayer(
    context: Context,
    viewId: Int,
    private val args: Map<String, Any>?,
    messenger: io.flutter.plugin.common.BinaryMessenger
) : PlatformView, YouTubePlayer.OnInitializedListener {

    private val playerView: YouTubePlayerView = YouTubePlayerView(context)
    private val channel = MethodChannel(messenger, "youtube_player_$viewId")
    private var youTubePlayer: YouTubePlayer? = null
    private var currentVideoId: String? = null

    init {
        setupMethodChannel()
        // FUTURE ENHANCEMENT: Pass API key securely from Dart via creationParams instead of hardcoding.
        val apiKey = args?.get("apiKey") as? String
        if (apiKey.isNullOrEmpty()) {
            Log.e(TAG, "API key is missing! Please supply a valid API key from Dart.")
            channel.invokeMethod("onError", "API key is missing")
        } else {
            try {
                // Initialize with the provided API key.
                playerView.initialize(apiKey, this)
                Log.i(TAG, "YouTubePlayerView initialized with API key")
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing YouTubePlayerView", e)
                channel.invokeMethod("onError", e.localizedMessage)
            }
        }
    }

    private fun setupMethodChannel() {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "loadVideo" -> {
                        val videoId = call.argument<String>("videoId")
                        if (videoId.isNullOrEmpty()) {
                            result.error("INVALID_VIDEO_ID", "Video ID is null or empty", null)
                        } else {
                            loadVideo(videoId)
                            result.success(null)
                        }
                    }
                    "play" -> {
                        youTubePlayer?.play()
                        result.success(null)
                    }
                    "pause" -> {
                        youTubePlayer?.pause()
                        result.success(null)
                    }
                    "seekTo" -> {
                        val position = call.argument<Int>("position")
                        if (position != null) {
                            youTubePlayer?.seekToMillis(position)
                            result.success(null)
                        } else {
                            result.error("INVALID_POSITION", "Position is null", null)
                        }
                    }
                    "setPlaybackRate" -> {
                        val rate = call.argument<Float>("rate")
                        if (rate != null) {
                            // Validate rate is one of the supported rates.
                            val playbackRate = when (rate) {
                                0.25f -> YouTubePlayer.PlaybackRate.RATE_0_25
                                0.5f -> YouTubePlayer.PlaybackRate.RATE_0_5
                                1.0f -> YouTubePlayer.PlaybackRate.RATE_1
                                1.5f -> YouTubePlayer.PlaybackRate.RATE_1_5
                                2.0f -> YouTubePlayer.PlaybackRate.RATE_2
                                else -> YouTubePlayer.PlaybackRate.RATE_1
                            }
                            youTubePlayer?.setPlaybackRate(playbackRate)
                            result.success(null)
                        } else {
                            result.error("INVALID_RATE", "Playback rate is null", null)
                        }
                    }
                    "setQuality" -> {
                        val quality = call.argument<String>("quality")
                        if (quality.isNullOrEmpty()) {
                            result.error("INVALID_QUALITY", "Quality is null or empty", null)
                        } else {
                            try {
                                // Uppercase quality to match enum names.
                                val qualityEnum = YouTubePlayer.PlaybackQuality.valueOf(quality.uppercase())
                                youTubePlayer?.setPlaybackQuality(qualityEnum)
                                result.success(null)
                            } catch (e: Exception) {
                                Log.e(TAG, "Invalid quality: $quality", e)
                                result.error("INVALID_QUALITY", e.localizedMessage, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error handling method call: ${call.method}", e)
                result.error("METHOD_CALL_ERROR", e.localizedMessage, null)
            }
        }
    }

    private fun loadVideo(videoId: String) {
        currentVideoId = videoId
        if (youTubePlayer == null) {
            // If the player isn't initialized yet, log a warning.
            Log.w(TAG, "Player not yet initialized; video will load when ready.")
        } else {
            Log.i(TAG, "Loading video: $videoId")
            youTubePlayer?.loadVideo(videoId)
        }
    }

    override fun onInitializationSuccess(
        provider: YouTubePlayer.Provider,
        player: YouTubePlayer,
        wasRestored: Boolean
    ) {
        youTubePlayer = player
        setupPlayerListeners(player)

        // If not restored, load the video from the creation params.
        if (!wasRestored) {
            args?.get("videoId")?.let {
                if (it is String && it.isNotEmpty()) {
                    currentVideoId = it
                    loadVideo(it)
                }
            }
        }
        channel.invokeMethod("onReady", null)
        Log.i(TAG, "Player initialized successfully")
    }

    override fun onInitializationFailure(
        provider: YouTubePlayer.Provider,
        error: YouTubeInitializationResult
    ) {
        Log.e(TAG, "Player initialization failed: $error")
        channel.invokeMethod("onError", error.toString())
        // FUTURE ENHANCEMENT: Implement a retry mechanism if initialization fails.
    }

    private fun setupPlayerListeners(player: YouTubePlayer) {
        player.setPlayerStateChangeListener(object : YouTubePlayer.PlayerStateChangeListener {
            override fun onLoading() {
                channel.invokeMethod("onStateChange", "loading")
                // FUTURE ENHANCEMENT: Consider sending buffering percentage if available.
            }
            
            override fun onLoaded(videoId: String) {
                channel.invokeMethod("onStateChange", "loaded")
            }
            
            override fun onVideoStarted() {
                channel.invokeMethod("onStateChange", "playing")
            }
            
            override fun onVideoEnded() {
                channel.invokeMethod("onStateChange", "ended")
            }
            
            override fun onError(error: YouTubePlayer.ErrorReason) {
                Log.e(TAG, "Player state error: $error")
                channel.invokeMethod("onError", error.toString())
            }

            override fun onAdStarted() {
                channel.invokeMethod("onStateChange", "ad_started")
            }
        })

        player.setPlaybackEventListener(object : YouTubePlayer.PlaybackEventListener {
            override fun onPlaying() {
                channel.invokeMethod("onStateChange", "playing")
            }
            
            override fun onPaused() {
                channel.invokeMethod("onStateChange", "paused")
            }
            
            override fun onStopped() {
                channel.invokeMethod("onStateChange", "stopped")
            }
            
            override fun onBuffering(isBuffering: Boolean) {
                channel.invokeMethod("onStateChange", if (isBuffering) "buffering" else "playing")
            }
            
            override fun onSeekTo(newPositionMillis: Int) {
                channel.invokeMethod("onTimeChange", newPositionMillis)
            }
        })
    }

    override fun getView() = playerView

    override fun dispose() {
        try {
            youTubePlayer?.release()
            Log.i(TAG, "Player released successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing player", e)
        }
    }
}
