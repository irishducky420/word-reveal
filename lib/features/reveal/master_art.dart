import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../domain/models/region.dart';

/// A drawable master image. Implementations must paint the FULL image into
/// the given rect; slicing into tiles is done by [paintMasterTile].
abstract class MasterImageSource {
  void paintFull(Canvas canvas, Rect rect);
}

/// Paints the slice of [source] described by [tile] (fractions of the full
/// image) into [destCell]. Works by painting the whole image scaled so that
/// exactly the requested fraction lands inside the clip - which makes
/// adjacent cells reconstruct the image with zero seams, because their
/// fractions share exact edges (see RegionSpec).
void paintMasterTile(
  Canvas canvas,
  MasterImageSource source,
  Rect destCell,
  RegionRect tile,
) {
  final fullW = destCell.width / tile.width;
  final fullH = destCell.height / tile.height;
  final fullRect = Rect.fromLTWH(
    destCell.left - tile.x0 * fullW,
    destCell.top - tile.y0 * fullH,
    fullW,
    fullH,
  );
  canvas.save();
  canvas.clipRect(destCell);
  source.paintFull(canvas, fullRect);
  canvas.restore();
}

/// Vector art drawn with Canvas. Resolution-independent: tiles stay crisp
/// at any cell size, and no image licensing is needed for the slice.
abstract class MasterArt implements MasterImageSource {
  @override
  void paintFull(Canvas canvas, Rect rect) => paint(UnitCanvas(canvas, rect));

  void paint(UnitCanvas u);
}

/// Raster master image (PNG/WebP bundled under assets/). Content can switch
/// to photographs with no engine change - see docs/CONTENT_GUIDE.md.
class RasterImageSource implements MasterImageSource {
  final ui.Image image;
  RasterImageSource(this.image);

  @override
  void paintFull(Canvas canvas, Rect rect) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.high,
    );
  }
}

/// Resolves an ImageProject.imageRef to a paintable source.
///   painter:<id>  -> built-in vector art
///   asset:<path>  -> raster image decoded from the asset bundle
class MasterArtRegistry {
  static final Map<String, MasterArt Function()> _painters = {
    'fox': FoxArt.new,
    'owl': OwlArt.new,
    'butterfly': ButterflyArt.new,
  };

  static final Map<String, MasterImageSource> _cache = {};

  static Future<MasterImageSource> resolve(String imageRef,
      {AssetBundle? bundle}) async {
    final cached = _cache[imageRef];
    if (cached != null) return cached;

    if (imageRef.startsWith('painter:')) {
      final id = imageRef.substring('painter:'.length);
      final builder = _painters[id];
      if (builder == null) {
        throw ArgumentError('Unknown painter art id: "$id"');
      }
      return _cache[imageRef] = builder();
    }
    if (imageRef.startsWith('asset:')) {
      final path = imageRef.substring('asset:'.length);
      final data = await (bundle ?? rootBundle).load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return _cache[imageRef] = RasterImageSource(frame.image);
    }
    throw ArgumentError('Unsupported imageRef: "$imageRef"');
  }
}

/// Unit-coordinate helper: art is authored in a [0..1] x [0..1] space and
/// mapped onto whatever rect is being painted.
class UnitCanvas {
  final Canvas canvas;
  final Rect rect;
  UnitCanvas(this.canvas, this.rect);

  Offset p(double x, double y) =>
      Offset(rect.left + x * rect.width, rect.top + y * rect.height);

  double sx(double v) => v * rect.width;
  double sy(double v) => v * rect.height;

  Rect r(double x0, double y0, double x1, double y1) =>
      Rect.fromPoints(p(x0, y0), p(x1, y1));

  void fillRect(double x0, double y0, double x1, double y1, Paint paint) =>
      canvas.drawRect(r(x0, y0, x1, y1), paint);

  void oval(double cx, double cy, double rx, double ry, Color color) =>
      canvas.drawOval(
        Rect.fromCenter(
            center: p(cx, cy), width: sx(rx * 2), height: sy(ry * 2)),
        Paint()..color = color,
      );

  void circle(double cx, double cy, double radius, Color color) =>
      canvas.drawCircle(p(cx, cy), sx(radius), Paint()..color = color);

  void path(List<Offset> unitPoints, Color color) {
    final path = Path()..moveTo(p(unitPoints.first.dx, unitPoints.first.dy).dx,
        p(unitPoints.first.dx, unitPoints.first.dy).dy);
    for (final pt in unitPoints.skip(1)) {
      final o = p(pt.dx, pt.dy);
      path.lineTo(o.dx, o.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void gradientRect(double x0, double y0, double x1, double y1,
      Color top, Color bottom) {
    final rect = r(x0, y0, x1, y1);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
  }

  void stroke(List<Offset> unitPoints, Color color, double widthFrac,
      {bool close = false}) {
    final path = Path()..moveTo(p(unitPoints.first.dx, unitPoints.first.dy).dx,
        p(unitPoints.first.dx, unitPoints.first.dy).dy);
    for (final pt in unitPoints.skip(1)) {
      final o = p(pt.dx, pt.dy);
      path.lineTo(o.dx, o.dy);
    }
    if (close) path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sx(widthFrac)
        ..strokeCap = StrokeCap.round,
    );
  }
}

/// ---- Wildlife collection artwork --------------------------------------
/// Bold flat shapes with high contrast, authored to stay readable when a
/// single cell shows only a small slice.

class FoxArt extends MasterArt {
  static const _orange = Color(0xFFE8762F);
  static const _darkOrange = Color(0xFFC75D1D);
  static const _cream = Color(0xFFFDF6EC);
  static const _dark = Color(0xFF3B2B20);

  @override
  void paint(UnitCanvas u) {
    // Warm sky + low sun.
    u.gradientRect(0, 0, 1, 0.66, const Color(0xFFFFE8C9), const Color(0xFFFFB36B));
    u.circle(0.78, 0.18, 0.10, const Color(0xFFFFF3D6));
    // Snow field.
    final ground = Path()
      ..moveTo(u.p(0, 0.66).dx, u.p(0, 0.66).dy)
      ..quadraticBezierTo(
          u.p(0.5, 0.56).dx, u.p(0.5, 0.56).dy, u.p(1, 0.66).dx, u.p(1, 0.66).dy)
      ..lineTo(u.p(1, 1).dx, u.p(1, 1).dy)
      ..lineTo(u.p(0, 1).dx, u.p(0, 1).dy)
      ..close();
    u.canvas.drawPath(ground, Paint()..color = const Color(0xFFF3F6FA));
    // Distant pines.
    u.path([const Offset(0.08, 0.64), const Offset(0.14, 0.48), const Offset(0.20, 0.64)], const Color(0xFF6E8B74));
    u.path([const Offset(0.16, 0.66), const Offset(0.23, 0.46), const Offset(0.30, 0.66)], const Color(0xFF587560));
    // Tail (wraps in front of the body), with white tip.
    u.oval(0.31, 0.80, 0.17, 0.095, _darkOrange);
    u.circle(0.165, 0.80, 0.062, _cream);
    // Body + chest.
    u.oval(0.54, 0.74, 0.175, 0.155, _orange);
    u.oval(0.54, 0.80, 0.095, 0.085, _cream);
    // Ears (outer + inner).
    u.path([const Offset(0.445, 0.46), const Offset(0.405, 0.295), const Offset(0.525, 0.405)], _orange);
    u.path([const Offset(0.635, 0.46), const Offset(0.675, 0.295), const Offset(0.555, 0.405)], _orange);
    u.path([const Offset(0.448, 0.435), const Offset(0.425, 0.33), const Offset(0.505, 0.405)], _dark);
    u.path([const Offset(0.632, 0.435), const Offset(0.655, 0.33), const Offset(0.575, 0.405)], _dark);
    // Head, snout, nose, eyes.
    u.circle(0.54, 0.50, 0.118, _orange);
    u.oval(0.54, 0.565, 0.068, 0.052, _cream);
    u.circle(0.54, 0.587, 0.019, _dark);
    u.circle(0.493, 0.487, 0.017, _dark);
    u.circle(0.587, 0.487, 0.017, _dark);
    // Front paws.
    u.oval(0.48, 0.885, 0.04, 0.025, _cream);
    u.oval(0.60, 0.885, 0.04, 0.025, _cream);
  }
}

class OwlArt extends MasterArt {
  static const _body = Color(0xFF7A5230);
  static const _wing = Color(0xFF65422A);
  static const _belly = Color(0xFFD9BC91);
  static const _amber = Color(0xFFE8A33D);
  static const _dark = Color(0xFF241A10);

  static const _stars = [
    Offset(0.10, 0.10), Offset(0.34, 0.07), Offset(0.50, 0.16),
    Offset(0.68, 0.08), Offset(0.86, 0.14), Offset(0.93, 0.32),
    Offset(0.06, 0.34), Offset(0.42, 0.28), Offset(0.78, 0.26),
    Offset(0.18, 0.52), Offset(0.90, 0.50), Offset(0.30, 0.40),
  ];

  @override
  void paint(UnitCanvas u) {
    // Night sky, stars, moon.
    u.gradientRect(0, 0, 1, 1, const Color(0xFF1B2350), const Color(0xFF2C3A6E));
    for (final s in _stars) {
      u.circle(s.dx, s.dy, 0.008, const Color(0xCCFFFFFF));
    }
    u.circle(0.22, 0.20, 0.115, const Color(0xFFF4EFD3));
    u.circle(0.185, 0.165, 0.024, const Color(0xFFE0D9B8));
    u.circle(0.255, 0.235, 0.018, const Color(0xFFE0D9B8));
    // Branch.
    u.stroke([const Offset(0.02, 0.85), const Offset(0.98, 0.83)], const Color(0xFF5B3A24), 0.045);
    u.stroke([const Offset(0.30, 0.845), const Offset(0.20, 0.94)], const Color(0xFF5B3A24), 0.025);
    // Body, wings, belly.
    u.oval(0.62, 0.60, 0.185, 0.235, _body);
    u.oval(0.475, 0.60, 0.075, 0.18, _wing);
    u.oval(0.765, 0.60, 0.075, 0.18, _wing);
    u.oval(0.62, 0.665, 0.115, 0.15, _belly);
    u.stroke([const Offset(0.56, 0.62), const Offset(0.62, 0.66), const Offset(0.68, 0.62)], const Color(0xFFB08F62), 0.012);
    u.stroke([const Offset(0.56, 0.70), const Offset(0.62, 0.74), const Offset(0.68, 0.70)], const Color(0xFFB08F62), 0.012);
    // Head + ear tufts.
    u.circle(0.62, 0.385, 0.15, _body);
    u.path([const Offset(0.505, 0.31), const Offset(0.49, 0.20), const Offset(0.585, 0.26)], _body);
    u.path([const Offset(0.735, 0.31), const Offset(0.75, 0.20), const Offset(0.655, 0.26)], _body);
    // Eyes + beak.
    u.circle(0.563, 0.375, 0.064, const Color(0xFFF2E8C9));
    u.circle(0.677, 0.375, 0.064, const Color(0xFFF2E8C9));
    u.circle(0.563, 0.375, 0.035, _amber);
    u.circle(0.677, 0.375, 0.035, _amber);
    u.circle(0.563, 0.375, 0.016, _dark);
    u.circle(0.677, 0.375, 0.016, _dark);
    u.path([const Offset(0.62, 0.41), const Offset(0.595, 0.465), const Offset(0.645, 0.465)], _amber);
    // Talons.
    u.circle(0.56, 0.835, 0.022, _amber);
    u.circle(0.68, 0.83, 0.022, _amber);
  }
}

class ButterflyArt extends MasterArt {
  static const _rim = Color(0xFF5A3214);
  static const _upper = Color(0xFFF28C28);
  static const _lower = Color(0xFFF2A93B);
  static const _bodyColor = Color(0xFF4A3320);

  @override
  void paint(UnitCanvas u) {
    // Sky + meadow.
    u.gradientRect(0, 0, 1, 1, const Color(0xFFBFE3F2), const Color(0xFFE8F7FB));
    final hill = Path()
      ..moveTo(u.p(0, 0.82).dx, u.p(0, 0.82).dy)
      ..quadraticBezierTo(
          u.p(0.5, 0.72).dx, u.p(0.5, 0.72).dy, u.p(1, 0.82).dx, u.p(1, 0.82).dy)
      ..lineTo(u.p(1, 1).dx, u.p(1, 1).dy)
      ..lineTo(u.p(0, 1).dx, u.p(0, 1).dy)
      ..close();
    u.canvas.drawPath(hill, Paint()..color = const Color(0xFF8CC56A));
    // Flowers.
    for (final f in const [
      (x: 0.14, y: 0.84, c: Color(0xFFE96A8D)),
      (x: 0.48, y: 0.88, c: Color(0xFFF2D24B)),
      (x: 0.84, y: 0.85, c: Color(0xFFFFFFFF)),
    ]) {
      u.stroke([Offset(f.x, f.y), Offset(f.x, f.y + 0.08)], const Color(0xFF5F8F45), 0.012);
      for (final d in const [(0.0, -0.025), (0.024, 0.012), (-0.024, 0.012)]) {
        u.circle(f.x + d.$1, f.y + d.$2, 0.018, f.c);
      }
      u.circle(f.x, f.y, 0.012, const Color(0xFFB9831F));
    }
    // Wings: dark rims, bright fills, white spots.
    u.oval(0.345, 0.335, 0.155, 0.13, _rim);
    u.oval(0.655, 0.335, 0.155, 0.13, _rim);
    u.oval(0.345, 0.335, 0.13, 0.107, _upper);
    u.oval(0.655, 0.335, 0.13, 0.107, _upper);
    u.oval(0.385, 0.525, 0.115, 0.10, _rim);
    u.oval(0.615, 0.525, 0.115, 0.10, _rim);
    u.oval(0.385, 0.525, 0.092, 0.079, _lower);
    u.oval(0.615, 0.525, 0.092, 0.079, _lower);
    u.circle(0.30, 0.30, 0.022, const Color(0xFFFFFFFF));
    u.circle(0.70, 0.30, 0.022, const Color(0xFFFFFFFF));
    u.circle(0.385, 0.385, 0.015, const Color(0xFFFFFFFF));
    u.circle(0.615, 0.385, 0.015, const Color(0xFFFFFFFF));
    // Body, head, antennae.
    u.canvas.drawRRect(
      RRect.fromRectAndRadius(
          u.r(0.478, 0.295, 0.522, 0.60), Radius.circular(u.sx(0.03))),
      Paint()..color = _bodyColor,
    );
    u.circle(0.50, 0.272, 0.030, _bodyColor);
    u.stroke([const Offset(0.49, 0.25), const Offset(0.44, 0.17)], _bodyColor, 0.010);
    u.stroke([const Offset(0.51, 0.25), const Offset(0.56, 0.17)], _bodyColor, 0.010);
    u.circle(0.44, 0.17, 0.012, _bodyColor);
    u.circle(0.56, 0.17, 0.012, _bodyColor);
  }
}
