import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n.dart';
import '../../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius = 18,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class AppListSection extends StatelessWidget {
  const AppListSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              color: context.appColors.mutedText,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: children.indexed.map((entry) {
              final index = entry.$1;
              final child = entry.$2;
              return Column(
                children: [
                  child,
                  if (index != children.length - 1)
                    const Divider(height: 1, indent: 64),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AppIconCircle(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: context.appColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right, color: context.appColors.navMuted),
          ],
        ),
      ),
    );
  }
}

class AppIconCircle extends StatelessWidget {
  const AppIconCircle({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 21,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class AppPanelHeader extends StatelessWidget {
  const AppPanelHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: context.appColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Tooltip(
          message: appT(context, 'close'),
          excludeFromSemantics: true,
          child: Semantics(
            container: true,
            label: appT(context, 'close'),
            button: true,
            onTap: () => Navigator.pop(context),
            excludeSemantics: true,
            child: Material(
              color: context.appColors.softFill,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.close,
                    color: context.appColors.mutedText,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AppPanelActions extends StatelessWidget {
  const AppPanelActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.cancelLabel = 'Cancel',
  });

  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: BorderSide(color: context.appColors.border, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onPrimaryPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}
