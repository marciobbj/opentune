import 'dart:math' as math;
import 'dart:ui';

/// Shared helpers to render waveform bars consistently across painters.

/// Reduces [data] to at most [count] values so each drawn bar maps to a whole
/// number of pixels. Drawing more bars than pixels makes them overlap and the
/// anti-aliasing produces uneven heights.
///
/// Each output value blends the group mean (sustained level) with the group
/// max (accents), mirroring how the extractor builds each bin.
List<double> resampleWaveform(List<double> data, int count) {
  final n = data.length;
  if (count <= 0 || n == 0) return const [];
  if (count >= n) return data;

  final out = List<double>.filled(count, 0.0);
  for (int i = 0; i < count; i++) {
    final start = (i * n) ~/ count;
    final end = math.max(start + 1, ((i + 1) * n) ~/ count);
    double sum = 0.0;
    double maxVal = 0.0;
    for (int j = start; j < end; j++) {
      final v = data[j];
      sum += v;
      if (v > maxVal) maxVal = v;
    }
    out[i] = (sum / (end - start)) * 0.6 + maxVal * 0.4;
  }
  return out;
}

/// Number of bars that fit in [width] given a target [slotWidth] (bar + gap).
int barCountFor(double width, int dataLength, {double slotWidth = 3.0}) {
  if (width <= 0) return 0;
  return math.max(1, math.min(dataLength, (width / slotWidth).floor()));
}

/// Draws a symmetric bar centered on [centerX]/[midY] whose total height is
/// exactly `2 * halfHeight` (rounded ends included), unlike a stroked line with
/// round caps, which overshoots by half the stroke width at each end.
void drawWaveformBar(
  Canvas canvas, {
  required double centerX,
  required double midY,
  required double halfHeight,
  required double width,
  required Paint paint,
}) {
  final rect = Rect.fromLTRB(
    centerX - width / 2,
    midY - halfHeight,
    centerX + width / 2,
    midY + halfHeight,
  );
  final radius = math.min(width / 2, halfHeight);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    paint,
  );
}
