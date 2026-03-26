// Head-only mood sticker using AliveAvatar in headOnly mode

import 'package:flutter/material.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/models/expression_state.dart';
import 'package:cerebro_app/widgets/alive_avatar.dart';

class MoodSticker extends StatelessWidget {
  final AvatarConfig config;
  final String mood;
  final double size;

  /// Optional zoom factor applied uniformly around the centered head.
  /// Default 0.42 → the head sits comfortably inside the sticker box
  /// with breathing room on all sides (no hair clip, no chin clip).
  /// Bump up toward 1.0+ if a caller wants the face to fill the frame.
  final double zoom;

  /// Scale origin for the zoom transform. Defaults to [Alignment.center]
  /// so the head sits centered in the frame. Passing something like
  /// [Alignment(0, 0.5)] biases the origin below center, which visually
  /// shifts the scaled head downward inside the sticker box — useful
  /// when a caller wants the face to hug the label below it instead of
  /// floating in the middle with a big empty gap underneath.
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
