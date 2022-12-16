// Copyright 2022 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'player_value.dart';

/// A widget the scaffolds the [YoutubePlayer]so that it can be moved around easily in the view
/// and handles the fullscreen functionality.
class YoutubePlayerScaffold extends StatefulWidget {
  /// Creates [YoutubePlayerScaffold].
  const YoutubePlayerScaffold({
    super.key,
    required this.builder,
    required this.controller,
    this.aspectRatio = 16 / 9,
    this.autoFullScreen = true,
    this.defaultOrientations = DeviceOrientation.values,
    this.gestureRecognizers,
    this.backgroundColor,
    this.userAgent,
  });

  /// Builds the child widget.
  final Widget Function(BuildContext context, Widget player) builder;

  /// The player controller.
  final YoutubePlayerController controller;

  /// The aspect ratio of the player.
  ///
  /// The value is ignored on fullscreen mode.
  final double aspectRatio;

  /// Whether the player should be fullscreen on device orientation changes.
  final bool autoFullScreen;

  /// The default orientations for the device.
  final List<DeviceOrientation> defaultOrientations;

  /// Which gestures should be consumed by the youtube player.
  ///
  /// This property is ignored in web.
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  /// The background color of the [WebView].
  final Color? backgroundColor;

  /// The value used for the HTTP User-Agent: request header.
  ///
  /// When null the platform's webview default is used for the User-Agent header.
  ///
  /// By default `userAgent` is null.
  final String? userAgent;

  @override
  State<YoutubePlayerScaffold> createState() => _YoutubePlayerScaffoldState();
}

class _YoutubePlayerScaffoldState extends State<YoutubePlayerScaffold> {
  late final GlobalObjectKey _playerKey;

  @override
  void initState() {
    super.initState();

    _playerKey = GlobalObjectKey(widget.controller);
  }

  @override
  Widget build(BuildContext context) {
    final player = KeyedSubtree(
      key: _playerKey,
      child: YoutubePlayer(
        controller: widget.controller,
        aspectRatio: widget.aspectRatio,
        gestureRecognizers: widget.gestureRecognizers,
        backgroundColor: widget.backgroundColor,
      ),
    );

    return YoutubePlayerControllerProvider(
      controller: widget.controller,
      child: kIsWeb
          ? widget.builder(context, player)
          : YoutubeValueBuilder(
              controller: widget.controller,
              buildWhen: (o, n) => o.fullScreenOption != n.fullScreenOption,
              builder: (context, value) {
                return _FullScreen(
                  auto: widget.autoFullScreen,
                  defaultOrientations: widget.defaultOrientations,
                  fullScreenOption: value.fullScreenOption,
                  child: Builder(
                    builder: (context) {
                      if (value.fullScreenOption.enabled) return player;

                      return widget.builder(context, player);
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _FullScreen extends StatefulWidget {
  const _FullScreen({
    required this.fullScreenOption,
    required this.defaultOrientations,
    required this.child,
    required this.auto,
  });

  final FullScreenOption fullScreenOption;
  final List<DeviceOrientation> defaultOrientations;
  final Widget child;
  final bool auto;

  @override
  State<_FullScreen> createState() => _FullScreenState();
}

class _FullScreenState extends State<_FullScreen> with WidgetsBindingObserver {
  Orientation? _previousOrientation;

  @override
  void initState() {
    super.initState();

    if (widget.auto) WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(_deviceOrientations);
    SystemChrome.setEnabledSystemUIMode(_uiMode);
  }

  @override
  void didUpdateWidget(_FullScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.fullScreenOption != widget.fullScreenOption) {
      SystemChrome.setPreferredOrientations(_deviceOrientations);
      SystemChrome.setEnabledSystemUIMode(_uiMode);
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    final orientation = MediaQuery.of(context).orientation;
    final controller = YoutubePlayerControllerProvider.of(context);
    final isFullScreen = controller.value.fullScreenOption.enabled;

    if (_previousOrientation == orientation) return;

    if (!isFullScreen && orientation == Orientation.landscape) {
      controller.enterFullScreen(lock: false);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    }

    _previousOrientation = orientation;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleFullScreenBackAction,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    if (widget.auto) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<DeviceOrientation> get _deviceOrientations {
    final fullscreen = widget.fullScreenOption;

    if (!fullscreen.enabled && fullscreen.locked) {
      return [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ];
    } else if (fullscreen.enabled) {
      return [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
    }

    return widget.defaultOrientations;
  }

  SystemUiMode get _uiMode {
    return widget.fullScreenOption.enabled
        ? SystemUiMode.immersive
        : SystemUiMode.edgeToEdge;
  }

  Future<bool> _handleFullScreenBackAction() async {
    if (mounted && widget.fullScreenOption.enabled) {
      YoutubePlayerControllerProvider.of(context).exitFullScreen();
      return false;
    }

    return true;
  }
}
