import 'package:flutter/material.dart';

import '../theme.dart';

/// بطاقة بيضاء بزوايا كبيرة وحد بيج رفيع كما في التصميم المرجعي.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: shape,
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
