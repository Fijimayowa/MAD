import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const SmileyApp());

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

enum FaceType { classic, sleepy, surprised }

extension FaceTypeLabel on FaceType {
  String get label => switch (this) {
    FaceType.classic => 'Classic',
    FaceType.sleepy => 'Sleepy',
    FaceType.surprised => 'Surprised',
  };
}

/// Face colour for each mood band (Level 2).
Color moodColor(double mood) {
  if (mood < 0.35) return const Color(0xFF7FB8E6); // cool blue
  if (mood <= 0.7) return const Color(0xFFFFD93B); // yellow
  return const Color(0xFFFF9F43); // warm orange
}

String moodLabel(double mood) {
  if (mood < 0.35) return 'Sad';
  if (mood <= 0.7) return 'Neutral';
  return 'Happy';
}

/// One snapshot of everything the user can change (Bonus: undo stack).
class FaceConfig {
  final double mood;
  final Color? customColor; // set by long-press, cleared when slider moves
  final FaceType type;
  final bool hat;
  final bool glasses;
  final bool mustache;

  const FaceConfig({
    this.mood = 0.85,
    this.customColor,
    this.type = FaceType.classic,
    this.hat = false,
    this.glasses = false,
    this.mustache = false,
  });

  Color get faceColor => customColor ?? moodColor(mood);

  FaceConfig copyWith({
    double? mood,
    Color? customColor,
    bool clearColor = false,
    FaceType? type,
    bool? hat,
    bool? glasses,
    bool? mustache,
  }) {
    return FaceConfig(
      mood: mood ?? this.mood,
      customColor: clearColor ? null : (customColor ?? this.customColor),
      type: type ?? this.type,
      hat: hat ?? this.hat,
      glasses: glasses ?? this.glasses,
      mustache: mustache ?? this.mustache,
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class SmileyPainter extends CustomPainter {
  final double mood;
  final Color faceColor;
  final FaceType type;
  final bool hat;
  final bool glasses;
  final bool mustache;

  const SmileyPainter({
    required this.mood,
    required this.faceColor,
    required this.type,
    this.hat = false,
    this.glasses = false,
    this.mustache = false,
  });

  static const Color _ink = Color(0xFF3E2723);

  /// Maps mood (0..1) to mouth curvature: -1 = deep frown, 0 = flat, 1 = big smile.
  static double _curve(double mood) {
    if (mood < 0.35) return -(0.35 - mood) / 0.35; // frown
    if (mood <= 0.7)
      return 0.05 + (mood - 0.35) / 0.35 * 0.35; // neutral / soft smile
    return 0.5 + (mood - 0.7) / 0.3 * 0.5; // big smile
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final cx = center.dx;
    final cy = center.dy;
    // Everything below is a fraction of the radius, so it scales to any size.
    final r = min(size.width, size.height) / 2 * 0.62;

    // Face: fill + border
    canvas.drawCircle(center, r, Paint()..color = faceColor);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = _ink,
    );

    // Eyes: symmetric offsets from the face centre
    final eyeDx = r * 0.38;
    final eyeY = cy - r * 0.22;
    final leftEye = Offset(cx - eyeDx, eyeY);
    final rightEye = Offset(cx + eyeDx, eyeY);
    _drawEye(canvas, leftEye, r);
    _drawEye(canvas, rightEye, r);

    _drawMouth(canvas, cx, cy, r);

    if (mustache) _drawMustache(canvas, cx, cy, r);
    if (glasses) _drawGlasses(canvas, leftEye, rightEye, r);
    if (hat) _drawHat(canvas, cx, cy, r);
  }

  void _drawEye(Canvas canvas, Offset e, double r) {
    final ink = Paint()..color = _ink;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round
      ..color = _ink;

    switch (type) {
      case FaceType.classic:
        canvas.drawCircle(e, r * 0.09, ink);
      case FaceType.sleepy:
        // closed eye: a small downward arc
        canvas.drawArc(
          Rect.fromCenter(center: e, width: r * 0.32, height: r * 0.2),
          0,
          pi,
          false,
          line,
        );
      case FaceType.surprised:
        canvas.drawCircle(e, r * 0.17, Paint()..color = Colors.white);
        canvas.drawCircle(e, r * 0.17, line);
        canvas.drawCircle(e, r * 0.07, ink);
    }
  }

  void _drawMouth(Canvas canvas, double cx, double cy, double r) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06
      ..strokeCap = StrokeCap.round
      ..color = _ink;

    if (type == FaceType.surprised) {
      final rect = Rect.fromCenter(
        center: Offset(cx, cy + r * 0.45),
        width: r * (0.22 + 0.12 * mood),
        height: r * (0.3 + 0.15 * mood),
      );
      canvas.drawOval(rect, Paint()..color = const Color(0xFF6D1B1B));
      canvas.drawOval(rect, line);
      return;
    }

    var curve = _curve(mood);
    if (type == FaceType.sleepy) curve = 0.2 + 0.2 * curve; // always soft
    final open = type == FaceType.classic && mood > 0.7;

    final h = max(r * 0.4 * curve.abs(), r * 0.02);
    final baseline = cy + r * (0.3 + 0.25 * max(0.0, -curve));
    final rect = Rect.fromCenter(
      center: Offset(cx, baseline),
      width: r * 0.9,
      height: h * 2,
    );

    if (curve >= 0) {
      // smile: lower half of the ellipse
      if (open) {
        canvas.drawArc(
          rect,
          0,
          pi,
          true,
          Paint()..color = const Color(0xFF8B1E2D),
        );
      }
      canvas.drawArc(rect, 0, pi, open, line);
    } else {
      // frown: upper half of the ellipse
      canvas.drawArc(rect, pi, pi, false, line);
    }
  }

  void _drawGlasses(Canvas canvas, Offset left, Offset right, double r) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..color = Colors.black87;
    final lens = r * 0.25;
    canvas.drawCircle(left, lens, p);
    canvas.drawCircle(right, lens, p);
    canvas.drawLine(
      Offset(left.dx + lens, left.dy),
      Offset(right.dx - lens, right.dy),
      p,
    );
  }

  void _drawMustache(Canvas canvas, double cx, double cy, double r) {
    final path = Path()
      ..moveTo(cx, cy + r * 0.1)
      ..quadraticBezierTo(
        cx - r * 0.2,
        cy - r * 0.02,
        cx - r * 0.45,
        cy + r * 0.12,
      )
      ..quadraticBezierTo(cx - r * 0.25, cy + r * 0.25, cx, cy + r * 0.17)
      ..quadraticBezierTo(
        cx + r * 0.25,
        cy + r * 0.25,
        cx + r * 0.45,
        cy + r * 0.12,
      )
      ..quadraticBezierTo(cx + r * 0.2, cy - r * 0.02, cx, cy + r * 0.1)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF4E342E));
  }

  void _drawHat(Canvas canvas, double cx, double cy, double r) {
    final hatColor = Paint()..color = const Color(0xFF263238);
    final brimY = cy - r * 0.95;
    // crown
    final crown = Rect.fromLTRB(
      cx - r * 0.47,
      brimY - r * 0.56,
      cx + r * 0.47,
      brimY,
    );
    canvas.drawRect(crown, hatColor);
    // red band
    canvas.drawRect(
      Rect.fromLTRB(
        crown.left,
        brimY - r * 0.16,
        crown.right,
        brimY - r * 0.04,
      ),
      Paint()..color = const Color(0xFFC62828),
    );
    // brim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, brimY),
          width: r * 1.5,
          height: r * 0.12,
        ),
        Radius.circular(r * 0.06),
      ),
      hatColor,
    );
  }

  @override
  bool shouldRepaint(covariant SmileyPainter old) {
    return old.mood != mood ||
        old.faceColor != faceColor ||
        old.type != type ||
        old.hat != hat ||
        old.glasses != glasses ||
        old.mustache != mustache;
  }
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class SmileyApp extends StatelessWidget {
  const SmileyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smiley Painter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
      ),
      home: const SmileyScreen(),
    );
  }
}

class SmileyScreen extends StatefulWidget {
  const SmileyScreen({super.key});

  @override
  State<SmileyScreen> createState() => _SmileyScreenState();
}

class _SmileyScreenState extends State<SmileyScreen> {
  FaceConfig _config = const FaceConfig();
  final List<FaceConfig> _undoStack = [];
  final Random _random = Random();

  /// Save the current configuration before any change (Bonus).
  void _saveForUndo() => _undoStack.add(_config);

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() => _config = _undoStack.removeLast());
    _showMessage('Undid last change');
  }

  /// One message at a time: clear old ones before showing the new one (Level 4).
  void _showMessage(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  void _selectFace(FaceType type) {
    if (type == _config.type) return;
    _saveForUndo();
    setState(() => _config = _config.copyWith(type: type));
  }

  void _cycleFace() {
    final next =
        FaceType.values[(_config.type.index + 1) % FaceType.values.length];
    _saveForUndo();
    setState(() => _config = _config.copyWith(type: next));
    _showMessage('Switched to ${next.label} face');
  }

  void _randomize() {
    final mood = _random.nextDouble();
    final color = HSLColor.fromAHSL(
      1,
      _random.nextDouble() * 360,
      0.7,
      0.65,
    ).toColor();
    _saveForUndo();
    setState(() => _config = _config.copyWith(mood: mood, customColor: color));
    _showMessage(
      'Randomized: mood ${(mood * 100).round()}% (${moodLabel(mood)}), new face color',
    );
  }

  void _toggle({bool? hat, bool? glasses, bool? mustache}) {
    _saveForUndo();
    setState(
      () => _config = _config.copyWith(
        hat: hat,
        glasses: glasses,
        mustache: mustache,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final side = min(width - 32, 320.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smiley Painter'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: _undoStack.isEmpty ? null : _undo,
          ),
        ],
      ),
      // ListView scrolls, so nothing overflows on small phones or landscape.
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: SizedBox(
              width: side,
              height: side,
              child: GestureDetector(
                onTap: _cycleFace,
                onLongPress: _randomize,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: SmileyPainter(
                    mood: _config.mood,
                    faceColor: _config.faceColor,
                    type: _config.type,
                    hat: _config.hat,
                    glasses: _config.glasses,
                    mustache: _config.mustache,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('Tap to change face · long-press to randomize'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<FaceType>(
              segments: [
                for (final t in FaceType.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {_config.type},
              onSelectionChanged: (s) => _selectFace(s.first),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Mood: ${moodLabel(_config.mood)} (${(_config.mood * 100).round()}%)',
          ),
          Slider(
            value: _config.mood,
            onChangeStart: (_) => _saveForUndo(),
            onChanged: (v) => setState(
              () => _config = _config.copyWith(mood: v, clearColor: true),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _accessoryButton(
                'Hat',
                Icons.checkroom,
                _config.hat,
                () => _toggle(hat: !_config.hat),
              ),
              _accessoryButton(
                'Glasses',
                Icons.visibility,
                _config.glasses,
                () => _toggle(glasses: !_config.glasses),
              ),
              _accessoryButton(
                'Mustache',
                Icons.face,
                _config.mustache,
                () => _toggle(mustache: !_config.mustache),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accessoryButton(
    String label,
    IconData icon,
    bool on,
    VoidCallback onTap,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: label,
          isSelected: on,
          icon: Icon(icon),
          selectedIcon: Icon(icon),
          onPressed: onTap,
        ),
        Text(label),
      ],
    );
  }
}
