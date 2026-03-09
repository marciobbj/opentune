import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Generates Instagram Stories-sized images (1080x1920) for sharing
/// what the user is currently listening to.
class ShareImageGenerator {
  static const double _width = 1080;
  static const double _height = 1920;

  /// Generates a share image with:
  /// - Blurred album art as background (if available)
  /// - A dark card in the center with:
  ///   - Simplified waveform visualization
  ///   - Track title
  ///   - Artist name
  ///   - OpenTune branding
  static Future<File?> generate({
    required String trackTitle,
    required String artistName,
    String? albumArtPath,
    List<double>? waveformData,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _width, _height));

      // 1. Draw background
      await _drawBackground(canvas, albumArtPath);

      // 2. Draw the center card
      await _drawCenterCard(canvas, trackTitle, artistName, waveformData);

      final picture = recorder.endRecording();
      final image = await picture.toImage(_width.toInt(), _height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/opentune_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      return file;
    } catch (e) {
      debugPrint('Error generating share image: $e');
      return null;
    }
  }

  static Future<void> _drawBackground(
    Canvas canvas,
    String? albumArtPath,
  ) async {
    if (albumArtPath != null && File(albumArtPath).existsSync()) {
      // Load the album art image
      final file = File(albumArtPath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _width.toInt(),
        targetHeight: _height.toInt(),
      );
      final frame = await codec.getNextFrame();
      final albumImage = frame.image;

      // Draw the album art scaled to fill
      // Calculate cover-fit rect
      final srcAspect = albumImage.width / albumImage.height;
      final dstAspect = _width / _height;
      Rect coverRect;
      if (srcAspect > dstAspect) {
        // Source is wider — crop sides
        final cropWidth = albumImage.height * dstAspect;
        final offsetX = (albumImage.width - cropWidth) / 2;
        coverRect = Rect.fromLTWH(
          offsetX,
          0,
          cropWidth,
          albumImage.height.toDouble(),
        );
      } else {
        // Source is taller — crop top/bottom
        final cropHeight = albumImage.width / dstAspect;
        final offsetY = (albumImage.height - cropHeight) / 2;
        coverRect = Rect.fromLTWH(
          0,
          offsetY,
          albumImage.width.toDouble(),
          cropHeight,
        );
      }

      final dstRect = Rect.fromLTWH(0, 0, _width, _height);

      // Draw blurred album art
      canvas.saveLayer(dstRect, Paint());
      canvas.drawImageRect(albumImage, coverRect, dstRect, Paint());

      // Apply blur effect by layering with a blurred paint
      canvas.drawRect(
        dstRect,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: 30,
            sigmaY: 30,
            tileMode: TileMode.clamp,
          ),
      );
      canvas.restore();

      // Re-draw blurred version
      canvas.saveLayer(dstRect, Paint());
      canvas.drawImageRect(
        albumImage,
        coverRect,
        dstRect,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: 60,
            sigmaY: 60,
            tileMode: TileMode.clamp,
          ),
      );
      canvas.restore();

      // Darken overlay for contrast
      canvas.drawRect(
        dstRect,
        Paint()..color = const Color(0xFF0A0E17).withValues(alpha: 0.55),
      );
    } else {
      // Fallback gradient background
      final gradientPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A0533),
            Color(0xFF0A0E17),
            Color(0xFF0D1B2A),
            Color(0xFF1B0A3C),
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, _width, _height));
      canvas.drawRect(Rect.fromLTWH(0, 0, _width, _height), gradientPaint);

      // Add subtle radial glow
      final glowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            const Color(0xFFFF6C08).withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, _width, _height));
      canvas.drawRect(Rect.fromLTWH(0, 0, _width, _height), glowPaint);
    }
  }

  static Future<void> _drawCenterCard(
    Canvas canvas,
    String trackTitle,
    String artistName,
    List<double>? waveformData,
  ) async {
    // Card dimensions & position (Matching original mockup)
    const cardWidth = 840.0;
    const cardHeight = 840.0;
    final cardX = (_width - cardWidth) / 2;
    final cardY = (_height - cardHeight) / 2;

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardX, cardY, cardWidth, cardHeight),
      const Radius.circular(32),
    );

    // Card background
    final cardPaint = Paint()
      ..color = const Color(
        0xFF030303,
      ).withValues(alpha: 0.95); // Very dark, almost solid black
    canvas.drawRRect(cardRect, cardPaint);

    // Card subtle border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.05);
    canvas.drawRRect(cardRect, borderPaint);

    // Waveform visualization - vertically balanced
    const waveformHeight = 160.0;
    final waveformY = cardY + 100.0; // Reduced top padding
    _drawWaveform(
      canvas,
      waveformData,
      Rect.fromLTWH(cardX + 60, waveformY, cardWidth - 120, waveformHeight),
    );

    // Track title - centered
    final titleParagraph = _buildParagraph(
      trackTitle,
      fontSize: 52,
      fontWeight: FontWeight.w700,
      color: const Color(0xFFF1F5F9),
      maxWidth: cardWidth - 80,
      maxLines: 2,
      textAlign: TextAlign.center,
    );

    // Artist name - centered
    final artistParagraph = _buildParagraph(
      artistName,
      fontSize: 34,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF94A3B8),
      maxWidth: cardWidth - 80,
      maxLines: 1,
      textAlign: TextAlign.center,
    );

    // Calculate vertical centering
    final availableTop = waveformY + waveformHeight;
    final availableBottom = cardY + cardHeight - 110.0; // Branding Y
    final totalTextHeight =
        titleParagraph.height + 16.0 + artistParagraph.height;

    final titleY =
        availableTop +
        (availableBottom - availableTop - totalTextHeight) / 2 -
        10.0; // Slight optical adjustment up
    final artistY = titleY + titleParagraph.height + 16.0;

    canvas.drawParagraph(titleParagraph, Offset(cardX + 40, titleY));
    canvas.drawParagraph(artistParagraph, Offset(cardX + 40, artistY));

    // OpenTune branding at bottom of card - centered
    await _drawBranding(canvas, cardX, cardY + cardHeight - 110, cardWidth);
  }

  static void _drawWaveform(
    Canvas canvas,
    List<double>? waveformData,
    Rect area,
  ) {
    // Simplify waveform to fit in the card
    const targetBars = 30;
    List<double> bars;

    if (waveformData != null && waveformData.isNotEmpty) {
      // Downsample the waveform data
      bars = List.generate(targetBars, (i) {
        final startIdx = (i * waveformData.length / targetBars).floor();
        final endIdx = ((i + 1) * waveformData.length / targetBars)
            .ceil()
            .clamp(0, waveformData.length);
        double sum = 0;
        int count = 0;
        for (int j = startIdx; j < endIdx; j++) {
          sum += waveformData[j];
          count++;
        }
        return count > 0 ? (sum / count).clamp(0.0, 1.0) : 0.0;
      });
    } else {
      // Generate demo waveform
      final random = math.Random(42);
      bars = List.generate(targetBars, (i) {
        final norm = i / targetBars;
        final envelope = math.sin(norm * math.pi) * 0.7 + 0.3;
        return (random.nextDouble() * 0.5 + 0.2) * envelope;
      });
    }

    final midY = area.top + area.height / 2;
    final maxBarHeight = area.height * 0.42;
    final barWidth = area.width / targetBars;
    final barGap = barWidth * 0.25;
    final barNetWidth = barWidth - barGap;

    for (int i = 0; i < bars.length; i++) {
      final x = area.left + i * barWidth + barGap / 2;
      final amplitude = bars[i].clamp(0.05, 1.0);
      final barHeight = math.max(amplitude * maxBarHeight, 3.0);

      // Gradient color based on position
      final t = i / bars.length;
      final color = Color.lerp(
        const Color(0xFFFF6C08), // primary orange
        const Color(0xFFFF9A4D), // lighter orange
        t,
      )!;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, midY - barHeight, barNetWidth, barHeight * 2),
        Radius.circular(barNetWidth / 2),
      );

      // Main bar
      canvas.drawRRect(barRect, Paint()..color = color.withValues(alpha: 0.9));

      // Subtle glow
      canvas.drawRRect(
        barRect,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Horizontal center line
    canvas.drawLine(
      Offset(area.left, midY),
      Offset(area.right, midY),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.05)
        ..strokeWidth = 1,
    );
  }

  static Future<void> _drawBranding(
    Canvas canvas,
    double cardX,
    double y,
    double cardWidth,
  ) async {
    const iconSize = 48.0;

    // Use a dummy paragraph to measure the width of the text
    final brandParagraphTemp = _buildParagraph(
      'OpenTune',
      fontSize: 44,
      fontWeight: FontWeight.w600,
      color: const Color(0xFFF1F5F9),
      maxWidth: 300,
      maxLines: 1,
      textAlign: TextAlign.left,
    );
    final textWidth = brandParagraphTemp.maxIntrinsicWidth;

    // Center icon and text together in the width of the card
    final totalWidth =
        iconSize + 16 + textWidth; // Added a little bit of margin
    final startX = cardX + (cardWidth - totalWidth) / 2;
    final iconX = startX;

    // Load the actual app icon from assets
    try {
      final byteData = await rootBundle.load('assets/icons/app_icon.png');
      final bytes = byteData.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: (iconSize * 4).toInt(), // 2x for sharpness
        targetHeight: (iconSize * 4).toInt(),
      );
      final frame = await codec.getNextFrame();
      final iconImage = frame.image;

      // Draw the app icon with rounded corners
      final iconRect = Rect.fromLTWH(iconX, y, iconSize, iconSize);
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(iconRect, const Radius.circular(8)),
      );
      canvas.drawImageRect(
        iconImage,
        Rect.fromLTWH(
          0,
          0,
          iconImage.width.toDouble(),
          iconImage.height.toDouble(),
        ),
        iconRect,
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
    } catch (e) {
      // Fallback: draw a simple colored square if icon can't be loaded
      final iconRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(iconX, y, iconSize, iconSize),
        const Radius.circular(8),
      );
      canvas.drawRRect(iconRect, Paint()..color = const Color(0xFFFF6C08));
    }

    // Brand text
    final brandParagraph = _buildParagraph(
      'OpenTune',
      fontSize: 44,
      fontWeight: FontWeight.w600,
      color: const Color(0xFFF1F5F9),
      maxWidth: cardWidth,
      maxLines: 1,
      textAlign: TextAlign.left,
    );
    canvas.drawParagraph(
      brandParagraph,
      Offset(iconX + iconSize + 16, y - 2),
    ); // Shifted to align with larger icon
  }

  static ui.Paragraph _buildParagraph(
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double maxWidth,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.left,
  }) {
    final style = ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: 'sans-serif',
    );

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: '…',
    );

    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(style)
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    return paragraph;
  }
}
