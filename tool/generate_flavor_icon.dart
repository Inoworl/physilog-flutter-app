import 'dart:io';

import 'package:image/image.dart' as img;

const _outputSize = 1024;
const _baseIconPath = 'assets/icons/icon_base.png';
const _generatedIconDir = 'assets/icons/generated';

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
  const alpha = 230;
  final red = config.color[0];
  final green = config.color[1];
  final blue = config.color[2];

  for (var y = 0; y < icon.height; y++) {
    for (var x = 0; x < icon.width; x++) {
      final diagonal = x + y - icon.width;
      final isInCorner = x > icon.width * 0.55 || y < icon.height * 0.45;
      final isInBadge = diagonal > -110 && diagonal < 220 && isInCorner;
      if (!isInBadge) {
        continue;
      }

      final pixel = icon.getPixel(x, y);
      final blendedRed = _blend(pixel.r, red, alpha);
      final blendedGreen = _blend(pixel.g, green, alpha);
      final blendedBlue = _blend(pixel.b, blue, alpha);
      icon.setPixelRgba(x, y, blendedRed, blendedGreen, blendedBlue, pixel.a);
    }
  }

  final label = img.Image(width: 300, height: 96, numChannels: 4);
  img.fill(label, color: img.ColorUint8.rgba(255, 255, 255, 0));

  final textWidth = config.label
      .split('')
      .fold<int>(
        0,
        (width, char) => width + img.arial48.characterXAdvance(char),
      );
  img.drawString(
    label,
    config.label,
    font: img.arial48,
    x: (label.width - textWidth) ~/ 2,
    y: 22,
    color: img.ColorUint8.rgba(255, 255, 255, 255),
  );

  final rotated = img.copyRotate(
    label,
    angle: 45,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    icon,
    rotated,
    dstX: icon.width - rotated.width + 16,
    dstY: -24,
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
