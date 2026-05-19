import 'dart:io';

import 'package:image/image.dart' as img;

const _outputSize = 1024;
const _baseIconPath = 'assets/icons/icon_base.png';
const _generatedIconDir = 'assets/icons/generated';
const _badgeAlpha = 230;
const _badgeLowerDiagonalRatio = 0.329;
const _badgeUpperDiagonalRatio = 0.635;
const _badgeLabelHeightRatio = 0.095;
const _badgeLabelCenterXRatio = 0.79;
const _badgeLabelCenterYRatio = 0.27;

const _flavors = {
  'dev': _FlavorIconConfig(label: 'DEV', color: [210, 45, 55]),
  'stg': _FlavorIconConfig(label: 'STG', color: [235, 145, 20]),
  'prod': _FlavorIconConfig(),
};

void main(List<String> args) {
  if (args.length != 1 ||
      (!_flavors.containsKey(args.single) && args.single != 'all')) {
    stderr.writeln(
      'Usage: dart run tool/generate_flavor_icon.dart <dev|stg|prod|all>',
    );
    exitCode = 64;
    return;
  }

  final targets = args.single == 'all' ? _flavors.keys : [args.single];
  for (final flavor in targets) {
    _generate(flavor, _flavors[flavor]!);
  }
}

void _generate(String flavor, _FlavorIconConfig config) {
  final source = img.decodePng(File(_baseIconPath).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Failed to decode $_baseIconPath');
    exitCode = 65;
    return;
  }

  final icon = img
      .copyResizeCropSquare(
        source,
        size: _outputSize,
        interpolation: img.Interpolation.cubic,
      )
      .convert(numChannels: 4);

  if (config.hasBadge) {
    _drawDiagonalBadge(icon, config);
  }

  final outputFile = File('$_generatedIconDir/icon_$flavor.png');
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsBytesSync(img.encodePng(icon));
  stdout.writeln('Generated ${outputFile.path}');
}

void _drawDiagonalBadge(img.Image icon, _FlavorIconConfig config) {
  final red = config.color[0];
  final green = config.color[1];
  final blue = config.color[2];
  final lowerDiagonal = (icon.width * _badgeLowerDiagonalRatio).round();
  final upperDiagonal = (icon.width * _badgeUpperDiagonalRatio).round();

  for (var y = 0; y < icon.height; y++) {
    for (var x = 0; x < icon.width; x++) {
      final diagonal = x - y;
      final isInBadge = diagonal >= lowerDiagonal && diagonal <= upperDiagonal;
      if (!isInBadge) {
        continue;
      }

      final pixel = icon.getPixel(x, y);
      final blendedRed = _blend(pixel.r, red, _badgeAlpha);
      final blendedGreen = _blend(pixel.g, green, _badgeAlpha);
      final blendedBlue = _blend(pixel.b, blue, _badgeAlpha);
      icon.setPixelRgba(x, y, blendedRed, blendedGreen, blendedBlue, pixel.a);
    }
  }

  final label = _buildBadgeLabel(config.label, icon.width);
  final rotated = img.copyRotate(
    label,
    angle: 45,
    interpolation: img.Interpolation.cubic,
  );
  _forceWhitePixels(rotated);
  img.compositeImage(
    icon,
    rotated,
    dstX: (icon.width * _badgeLabelCenterXRatio - rotated.width / 2).round(),
    dstY: (icon.height * _badgeLabelCenterYRatio - rotated.height / 2).round(),
  );
}

img.Image _buildBadgeLabel(String text, int iconSize) {
  final raw = img.Image(width: 360, height: 120, numChannels: 4);
  img.fill(raw, color: img.ColorUint8.rgba(255, 255, 255, 0));

  final textWidth = text
      .split('')
      .fold<int>(
        0,
        (width, char) => width + img.arial48.characterXAdvance(char),
      );
  img.drawString(
    raw,
    text,
    font: img.arial48,
    x: (raw.width - textWidth) ~/ 2,
    y: 36,
    color: img.ColorUint8.rgba(255, 255, 255, 255),
  );

  final bounds = _findOpaqueBounds(raw);
  final cropped = img.copyCrop(
    raw,
    x: bounds.x,
    y: bounds.y,
    width: bounds.width,
    height: bounds.height,
  );
  final targetHeight = (iconSize * _badgeLabelHeightRatio).round();
  final targetWidth = (cropped.width * targetHeight / cropped.height).round();
  final scaled = img.copyResize(
    cropped,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );
  _forceWhitePixels(scaled);
  final padding = (iconSize * 0.02).round();
  final label = img.Image(
    width: scaled.width + padding * 2,
    height: scaled.height + padding * 2,
    numChannels: 4,
  );
  img.fill(label, color: img.ColorUint8.rgba(255, 255, 255, 0));
  img.compositeImage(label, scaled, dstX: padding, dstY: padding);

  return label;
}

void _forceWhitePixels(img.Image image) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.a == 0) {
        continue;
      }
      image.setPixelRgba(x, y, 255, 255, 255, pixel.a);
    }
  }
}

_ImageBounds _findOpaqueBounds(img.Image image) {
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a == 0) {
        continue;
      }
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX == -1) {
    return const _ImageBounds(x: 0, y: 0, width: 1, height: 1);
  }

  return _ImageBounds(
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

int _blend(num base, int overlay, int alpha) {
  return ((base * (255 - alpha) + overlay * alpha) / 255).round();
}

class _FlavorIconConfig {
  const _FlavorIconConfig({this.label = '', this.color = const [0, 0, 0]});

  final String label;
  final List<int> color;

  bool get hasBadge => label.isNotEmpty;
}

class _ImageBounds {
  const _ImageBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;
}
