// Head-only mood sticker — wraps AliveAvatar in headOnly mode.

import 'package:flutter/material.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/models/expression_state.dart';
import 'package:cerebro_app/widgets/alive_avatar.dart';

class MoodSticker extends StatelessWidget {
  final AvatarConfig config;
  final String mood;
  final double size;

  /// Zoom factor around the centered head. Default 0.42 fits comfortably.
  final double zoom;

  /// Scale origin for zoom. Adjust to shift the head within the box.
  final Alignment scaleAlignment;

  const MoodSticker({
    super.key,
    required this.config,
    required this.mood,
    this.size = 80,
    this.zoom = 0.42,
    this.scaleAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final expression = ExpressionEngine.fromMood(mood);

    // Render the avatar at the full sticker box size so the layer
    // positions stay consistent with the home / profile rendering, then
    // optionally shrink the whole thing down with Transform.scale so the
    // head occupies less of the box. zoom < 1.0 gives padding around the
    // head; zoom > 1.0 zooms in / clips the edges.
    final avatar = AliveAvatar(
      config: config,
      size: size,
      expression: expression,
      headOnly: true,
      breathing: false,
    );

    // Always clip at the sticker boundary — AliveAvatar no longer
    // internally clips in headOnly mode (so hair + chin aren't chopped),
    // which means the head may extend past the size x size box before we
    // scale it. ClipRect guarantees it can't bleed into siblings.
    final child = zoom == 1.0
        ? avatar
        : Transform.scale(
            scale: zoom,
            alignment: scaleAlignment,
            child: avatar,
          );

    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(child: child),
    );
  }
}
