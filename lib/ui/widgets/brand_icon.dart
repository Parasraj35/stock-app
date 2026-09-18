import 'package:flutter/material.dart';

import '../theme/tokens.dart';

const _brandIconAssets = {
  'crush': 'assets/brand_icons/crush.png',
  'danedar': 'assets/brand_icons/danedar.png',
  'ghera': 'assets/brand_icons/ghera.png',
  'khaka': 'assets/brand_icons/khaka.png',
  'mitti': 'assets/brand_icons/mitti.png',
  'retti': 'assets/brand_icons/retti.png',
  'silica': 'assets/brand_icons/retti.png',
};

String? _assetFor(String brandName) {
  final n = brandName.toLowerCase();
  for (final entry in _brandIconAssets.entries) {
    if (n.contains(entry.key)) return entry.value;
  }
  return null;
}

/// Rounded-square material thumbnail for a brand — uses the real icon asset
/// when the brand name matches a known material, otherwise a generic swatch
/// (so custom/future brand names still render something reasonable).
class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key, required this.name, this.size = 48});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = _assetFor(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: asset != null
          ? Image.asset(asset, fit: BoxFit.contain)
          : Icon(
              Icons.landscape_outlined,
              color: AppColors.primary,
              size: size * 0.55,
            ),
    );
  }
}
