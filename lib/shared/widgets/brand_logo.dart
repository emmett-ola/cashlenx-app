import 'package:flutter/material.dart';

enum BrandLogoTone { original, white }

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.tone = BrandLogoTone.original,
  });

  static const assetPath = 'assets/images/brand_mark.png';

  final double? width;
  final double? height;
  final BoxFit fit;
  final BrandLogoTone tone;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
    );

    if (tone == BrandLogoTone.white) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: image,
      );
    }

    return image;
  }
}
