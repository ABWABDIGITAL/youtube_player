// ios/Classes/YouTubePlayerPlugin.swift
import Flutter
import UIKit
import YouTubeiOSPlayerHelper

public class YouTubePlayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = YouTubePlayerFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "youtube_player_view")
    NSLog("[NativeYouTubePlayer] Plugin registered")
  }
}

class YouTubePlayerFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return NativeYouTubePlayer(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

class NativeYouTubePlayer: NSObject, FlutterPlatformView, YTPlayerViewDelegate {
  private let playerView: YTPlayerView
  private let channel: FlutterMethodChannel
  private var currentVideoId: String?
  // Store API key if provided from Dart.
  private var apiKey: String?

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    // Initialize playerView with the given frame.
    playerView = YTPlayerView(frame: frame)
    channel = FlutterMethodChannel(
      name: "youtube_player_\(viewId)",
      binaryMessenger: messenger
    )
    super.init()
    
    playerView.delegate = self
    setupMethodChannel()
    
    // Retrieve API key and videoId from creation parameters.
    if let params = args as? [String: Any] {
      apiKey = params["apiKey"] as? String
      if let videoId = params["videoId"] as? String {
        currentVideoId = videoId
      }
    }
    
    // Ensure an API key is provided.
    guard let validApiKey = apiKey, !validApiKey.isEmpty else {
      NSLog("[NativeYouTubePlayer] API key is missing! Please provide a valid API key from Dart.")
      channel.invokeMethod("onError", arguments: "API key is missing")
      return
    }
    
    // Initialize playerView with the provided API key.
    // FUTURE ENHANCEMENT: Consider a secure way to store and retrieve the API key.
    playerView.initialize(validApiKey, playerVars: ["playsinline": 1]) { [weak self] success, error in
      if success {
        NSLog("[NativeYouTubePlayer] YouTubePlayerView initialized successfully with API key")
        // If a videoId was provided in the creation parameters, load it now.
        if let videoId = self?.currentVideoId, !videoId.isEmpty {
          self?.loadVideo(videoId: videoId)
        }
      } else {
        let errMsg = error?.localizedDescription ?? "Unknown error"
        NSLog("[NativeYouTubePlayer] Error initializing player view: \(errMsg)")
        self?.channel.invokeMethod("onError", arguments: errMsg)
      }
    }
  }

  private func setupMethodChannel() {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      
      switch call.method {
      case "loadVideo":
        if let videoId = call.arguments as? String, !videoId.isEmpty {
          self.loadVideo(videoId: videoId)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_VIDEO_ID", message: "Video ID is null or empty", details: nil))
        }
      case "play":
        self.playerView.playVideo()
        result(nil)
      case "pause":
        self.playerView.pauseVideo()
        result(nil)
      case "seekTo":
        if let seconds = call.arguments as? Float {
          self.playerView.seek(toSeconds: seconds, allowSeekAhead: true)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_POSITION", message: "Position is null", details: nil))
        }
      case "setPlaybackRate":
        if let rate = call.arguments as? Float {
          self.playerView.setPlaybackRate(rate)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_RATE", message: "Playback rate is null", details: nil))
        }
      case "setQuality":
        if let quality = call.arguments as? String, !quality.isEmpty {
          self.playerView.setPlaybackQuality(quality)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_QUALITY", message: "Quality is null or empty", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func loadVideo(videoId: String) {
    currentVideoId = videoId
    NSLog("[NativeYouTubePlayer] Loading video: \(videoId)")
    playerView.load(withVideoId: videoId)
  }

  func view() -> UIView {
    return playerView
  }

  // MARK: - YTPlayerViewDelegate Methods

  func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
    NSLog("[NativeYouTubePlayer] Player ready")
    channel.invokeMethod("onReady", arguments: nil)
  }

  func playerView(_ playerView: YTPlayerView, didChangeTo state: YTPlayerState) {
    let stateString: String
    switch state {
    case .unstarted: stateString = "unstarted"
    case .ended: stateString = "ended"
    case .playing: stateString = "playing"
    case .paused: stateString = "paused"
    case .buffering: stateString = "buffering"
    case .queued: stateString = "queued"
    default: stateString = "unknown"
    }
    NSLog("[NativeYouTubePlayer] State changed: \(stateString)")
    channel.invokeMethod("onStateChange", arguments: stateString)
  }
  
  func playerView(_ playerView: YTPlayerView, didPlayTime playTime: Float) {
    let millis = Int(playTime * 1000)
    channel.invokeMethod("onTimeChange", arguments: millis)
  }
  
  func playerView(_ playerView: YTPlayerView, receivedError error: YTPlayerError) {
    let errorString = error.rawValue
    NSLog("[NativeYouTubePlayer] Received error: \(errorString)")
    channel.invokeMethod("onError", arguments: errorString)
  }
  
  // MARK: - Additional Recommendations & Future Enhancements:
  // 1. Consider adding buffering updates: If YTPlayerView provides buffering progress,
  //    relay this information via an additional method call (e.g., "onBuffering").
  // 2. Expose more granular event streams using Flutter's EventChannel if required.
  // 3. Implement full-screen toggling on the native side and expose that via MethodChannel.
  // 4. Provide configuration for controls, e.g., automatically hide native controls and
  //    let Flutter render custom overlays.
  // 5. Ensure that API key and sensitive data are handled securely.

  func dispose() {
    do {
      playerView.stopVideo()
      NSLog("[NativeYouTubePlayer] Stopped video playback")
      // YouTubeiOSPlayerHelper does not provide an explicit release method,
      // but you may perform additional cleanup if needed.
    } catch {
      NSLog("[NativeYouTubePlayer] Error stopping video: \(error.localizedDescription)")
    }
  }
}
