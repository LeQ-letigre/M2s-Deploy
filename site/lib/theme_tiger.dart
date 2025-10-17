// lib/theme_tiger.dart
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 🐅 Thème global TIGRES — fond orangé plus visible
class Tiger {
  // ---------------------------------------------------------------------------
  // 🌑 MODE SOMBRE
  // ---------------------------------------------------------------------------
  static final ThemeData dark = ThemeData.dark().copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF000000),
    colorScheme: const ColorScheme.dark(
      primary: Colors.orangeAccent,
      secondary: Colors.deepOrange,
      surface: Color(0xFF141414),
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A),
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.orangeAccent),
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white),
      labelLarge: TextStyle(color: Colors.orangeAccent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: tigerButton()),
    switchTheme: tigerSwitchTheme(isDark: true),
  );

  // ---------------------------------------------------------------------------
  // ☀️ MODE CLAIR
  // ---------------------------------------------------------------------------
  static final ThemeData light = ThemeData.light().copyWith(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: Colors.deepOrangeAccent,
      secondary: Colors.orange,
      surface: Colors.white,
      onSurface: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      iconTheme: IconThemeData(color: Colors.deepOrangeAccent),
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.black87),
      titleLarge: TextStyle(color: Colors.black),
      labelLarge: TextStyle(color: Colors.deepOrangeAccent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: tigerButton(
        background: Colors.deepOrangeAccent,
        foreground: Colors.white,
      ),
    ),
    switchTheme: tigerSwitchTheme(isDark: false),
  );

  // ---------------------------------------------------------------------------
  // 🧱 STYLE DES BOUTONS
  // ---------------------------------------------------------------------------
  static ButtonStyle tigerButton({Color? background, Color? foreground}) {
    return ElevatedButton.styleFrom(
      backgroundColor: background ?? Colors.orangeAccent,
      foregroundColor: foreground ?? Colors.black,
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size(160, 50),
      elevation: 2,
    );
  }

  // ---------------------------------------------------------------------------
  // 🐯 FOND DYNAMIQUE TIGRE (dégradé + rayures)
  // ---------------------------------------------------------------------------
  static BoxDecoration tigerBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> baseColors = isDark
        ? [const Color(0xFF0E0E0E), const Color(0xFF1A1A1A)]
        : [const Color(0xFFFFF4E5), const Color(0xFFFFFFFF)];

    return BoxDecoration(
      gradient: LinearGradient(
        colors: baseColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      image: DecorationImage(
        image: _TigerStripePainter.generate(isDark),
        repeat: ImageRepeat.repeat,
        opacity: isDark ? 0.08 : 0.15, // ✅ plus visible
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🧩 SWITCHS
  // ---------------------------------------------------------------------------
  static SwitchThemeData tigerSwitchTheme({required bool isDark}) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (states) => states.contains(WidgetState.selected)
            ? (isDark ? Colors.orangeAccent : Colors.deepOrangeAccent)
            : (isDark ? Colors.white : Colors.black54),
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (states) => states.contains(WidgetState.selected)
            ? (isDark
                  ? Colors.orangeAccent.withValues(alpha: 0.4)
                  : Colors.deepOrangeAccent.withValues(alpha: 0.3))
            : (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1)),
      ),
    );
  }
}

/// 🎨 Motif rayures TIGRE bien visible
class _TigerStripePainter extends ImageProvider<_TigerStripePainter> {
  final bool isDark;
  const _TigerStripePainter._(this.isDark);
  static _TigerStripePainter generate(bool isDark) =>
      _TigerStripePainter._(isDark);

  @override
  Future<_TigerStripePainter> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_TigerStripePainter>(this);

  @override
  ImageStreamCompleter loadImage(
    _TigerStripePainter key,
    Future<ui.Codec> Function(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSize Function(int, int)? getTargetSize,
    })
    decode,
  ) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = ui.Size(300, 300);

    // Fond
    final bg = Paint()
      ..color = isDark ? const Color(0xFF101010) : const Color(0xFFFFFAF3);
    canvas.drawRect(Offset.zero & size, bg);

    // Rayures diagonales plus visibles
    final stripePaint = Paint()
      ..color = isDark
          ? Colors.deepOrangeAccent.withValues(alpha: 0.18)
          : Colors.orangeAccent.withValues(alpha: 0.25)
      ..strokeWidth = 55
      ..strokeCap = StrokeCap.round;

    for (double i = -80; i < size.width + 100; i += 100) {
      canvas.drawLine(Offset(i, 0), Offset(i + 90, size.height), stripePaint);
    }

    // Un léger voile de lumière orangée
    final overlay = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size.width, size.height),
        [
          Colors.transparent,
          (isDark
              ? Colors.orangeAccent.withValues(alpha: 0.07)
              : Colors.deepOrangeAccent.withValues(alpha: 0.10)),
        ],
      );
    canvas.drawRect(Offset.zero & size, overlay);

    final picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(
      size.width.toInt(),
      size.height.toInt(),
    );

    final completer = Completer<ImageInfo>();
    image.toByteData(format: ui.ImageByteFormat.png).then((byteData) async {
      if (byteData == null) {
        completer.completeError(StateError('Image byteData is null'));
        return;
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        byteData.buffer.asUint8List(),
      );
      final ui.Codec codec = await decode(buffer);
      final ui.FrameInfo frame = await codec.getNextFrame();
      completer.complete(ImageInfo(image: frame.image, scale: 1));
    });

    return OneFrameImageStreamCompleter(completer.future);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TigerStripePainter && other.isDark == isDark;

  @override
  int get hashCode => isDark.hashCode;
}
