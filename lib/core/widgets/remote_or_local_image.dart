import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RemoteOrLocalImage extends StatelessWidget {
  const RemoteOrLocalImage({
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    super.key,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return CachedNetworkImage(
        imageUrl: source,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        placeholder: (context, url) => _placeholder(),
        errorWidget: (context, url, error) => _placeholder(),
      );
    }
    return Image.file(
      File(source),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (context, error, stack) => _placeholder(),
    );
  }

  Widget _placeholder() => SizedBox(
    width: width,
    height: height,
    child: const ColoredBox(
      color: AppColors.fond,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppColors.bleu),
      ),
    ),
  );
}
