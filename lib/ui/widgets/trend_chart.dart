import 'package:flutter/material.dart';

import '../../core/trends.dart' show TrendPoint;
import '../theme/tokens.dart';

enum ChartStyle { line, bar }

/// Bigger, dependency-free trend chart (line or bar) for the Dashboard's
/// profit trend section — same hand-rolled CustomPainter approach as the
/// old sparkline, just with a zero baseline and date labels.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.style,
    required this.positiveColor,
    required this.negativeColor,
    this.height = 170,
  });

  final List<TrendPoint> points;
  final ChartStyle style;
  final Color positiveColor;
  final Color negativeColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return SizedBox(height: height);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _TrendChartPainter(
          points: points,
          style: style,
          positiveColor: positiveColor,
          negativeColor: negativeColor,
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.points,
    required this.style,
    required this.positiveColor,
    required this.negativeColor,
  });

  final List<TrendPoint> points;
  final ChartStyle style;
  final Color positiveColor;
  final Color negativeColor;

  static const _labelHeight = 18.0;
  static const _maxLabels = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - _labelHeight;
    final values = points.map((p) => p.value).toList();
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (minV > 0) minV = 0;
    if (maxV < 0) maxV = 0;
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;

    double yFor(double v) => chartHeight * (1 - (v - minV) / range);
    final zeroY = yFor(0);

    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = AppColors.divider
        ..strokeWidth = 1,
    );

    if (style == ChartStyle.bar) {
      _paintBars(canvas, size.width, values, yFor, zeroY);
    } else {
      _paintLine(canvas, size.width, values, chartHeight, yFor);
    }

    _paintLabels(canvas, size);
  }

  void _paintBars(
    Canvas canvas,
    double width,
    List<double> values,
    double Function(double) yFor,
    double zeroY,
  ) {
    final n = values.length;
    final slotWidth = width / n;
    final barWidth = (slotWidth * 0.5).clamp(2.0, 22.0);
    for (var i = 0; i < n; i++) {
      final cx = slotWidth * i + slotWidth / 2;
      final v = values[i];
      final top = v >= 0 ? yFor(v) : zeroY;
      var bottom = v >= 0 ? zeroY : yFor(v);
      if (bottom == top) bottom = top + 1.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - barWidth / 2, top, cx + barWidth / 2, bottom),
          const Radius.circular(3),
        ),
        Paint()..color = v >= 0 ? positiveColor : negativeColor,
      );
    }
  }

  void _paintLine(
    Canvas canvas,
    double width,
    List<double> values,
    double chartHeight,
    double Function(double) yFor,
  ) {
    final n = values.length;
    final color = values.last >= 0 ? positiveColor : negativeColor;
    Offset pointAt(int i) => Offset(width * i / (n - 1), yFor(values[i]));

    final linePath = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < n; i++) {
      linePath.lineTo(pointAt(i).dx, pointAt(i).dy);
    }
    final fillPath = Path.from(linePath)
      ..lineTo(width, chartHeight)
      ..lineTo(0, chartHeight)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, chartHeight)),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(pointAt(n - 1), 3.5, Paint()..color = color);
  }

  void _paintLabels(Canvas canvas, Size size) {
    final n = points.length;
    final step = (n / _maxLabels).ceil().clamp(1, n);
    for (var i = 0; i < n; i += step) {
      final date = points[i].date;
      final text = '${date.day}/${date.month}';
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (size.width * i / (n - 1)) - tp.width / 2;
      tp.paint(
        canvas,
        Offset(
          x.clamp(0, size.width - tp.width),
          size.height - _labelHeight + 3,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.style != style ||
      oldDelegate.positiveColor != positiveColor ||
      oldDelegate.negativeColor != negativeColor;
}
