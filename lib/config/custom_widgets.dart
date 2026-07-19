import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:lottie/lottie.dart';
import 'design_system.dart';

/// Custom reusable widgets following StyleStack design system

class StyleStackCard extends StatelessWidget {
  const StyleStackCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = DesignSystem.radiusLg,
    this.padding = const EdgeInsets.all(DesignSystem.spacingLg),
    this.margin = EdgeInsets.zero,
    this.backgroundColor = DesignSystem.surface,
    this.hasShadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color backgroundColor;
  final bool hasShadow;

  @override
  Widget build(BuildContext context) {
    final base = context.theme.cardStyle;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow ? DesignSystem.shadowSoft : null,
      ),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: FCard(
          clipBehavior: Clip.antiAlias,
          style: FCardStyle(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: DesignSystem.border),
            ),
            titleTextStyle: base.titleTextStyle,
            subtitleTextStyle: base.subtitleTextStyle,
            padding: padding,
          ),
          builder: (context, style, child) =>
              Padding(padding: style.padding, child: child),
          child: child,
        ),
      ),
    );
  }
}

class StyleStackButton extends StatelessWidget {
  const StyleStackButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = _ButtonVariant.filled,
    this.size = _ButtonSize.medium,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final _ButtonVariant variant;
  final _ButtonSize size;

  @override
  Widget build(BuildContext context) {
    final isDisabled = isLoading;
    final foruiVariant = switch (variant) {
      _ButtonVariant.filled => FButtonVariant.primary,
      _ButtonVariant.outlined => FButtonVariant.outline,
      _ButtonVariant.text => FButtonVariant.ghost,
    };
    final foruiSize = switch (size) {
      _ButtonSize.small => FButtonSizeVariant.sm,
      _ButtonSize.medium => FButtonSizeVariant.md,
      _ButtonSize.large => FButtonSizeVariant.lg,
    };

    final height = switch (size) {
      _ButtonSize.small => 40.0,
      _ButtonSize.medium => 44.0,
      _ButtonSize.large => 48.0,
    };

    return SizedBox(
      height: height,
      child: FButton.raw(
        onPress: isDisabled ? null : onPressed,
        variant: foruiVariant,
        size: foruiSize,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.spacingMd,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const FCircularProgress.loader(size: .sm)
                else if (icon != null)
                  Icon(icon),
                if (isLoading || icon != null)
                  const SizedBox(width: DesignSystem.spacingSm),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ButtonVariant { filled, outlined, text }

enum _ButtonSize { small, medium, large }

abstract final class StyleStackMotionAssets {
  static const universalLoader =
      'assets/animations/capsule_wardrobe_carousel.json';
  static const outfitDesigner = 'assets/animations/digital_designer.json';
  static const emptyCloset = 'assets/animations/closet.json';
}

class StyleStackLoadingIndicator extends StatelessWidget {
  const StyleStackLoadingIndicator({
    super.key,
    this.message = 'Loading…',
    this.animationAsset = StyleStackMotionAssets.universalLoader,
    this.animationSize = 180,
    this.padding = const EdgeInsets.all(DesignSystem.spacingXl),
  });

  final String message;
  final String animationAsset;
  final double animationSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RepaintBoundary(
                child: SizedBox.square(
                  dimension: animationSize,
                  child: Lottie.asset(
                    animationAsset,
                    repeat: true,
                    fit: BoxFit.contain,
                    frameRate: FrameRate.max,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: FCircularProgress.loader(size: .md),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DesignSystem.spacingMd),
              ExcludeSemantics(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DesignSystem.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StyleStackEmptyState extends StatelessWidget {
  const StyleStackEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.animationAsset,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? animationAsset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignSystem.spacingxxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (animationAsset != null)
              RepaintBoundary(
                child: SizedBox.square(
                  dimension: 210,
                  child: Lottie.asset(
                    animationAsset!,
                    repeat: true,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(icon, size: 56, color: DesignSystem.primary),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(DesignSystem.spacingXl),
                decoration: BoxDecoration(
                  color: DesignSystem.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
                ),
                child: Icon(icon, size: 56, color: DesignSystem.primary),
              ),
            const SizedBox(height: DesignSystem.spacingXl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: DesignSystem.spacingMd),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignSystem.textSecondary,
                ),
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: DesignSystem.spacingXl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class StyleStackFilterChip extends StatelessWidget {
  const StyleStackFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: DesignSystem.spacingSm),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        backgroundColor: DesignSystem.surfaceAlt,
        selectedColor: DesignSystem.secondary.withOpacity(0.2),
        side: BorderSide(
          color: isSelected ? DesignSystem.primary : Colors.transparent,
          width: isSelected ? 1.5 : 0,
        ),
        labelStyle: TextStyle(
          color: isSelected ? DesignSystem.primary : DesignSystem.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
        ),
      ),
    );
  }
}

class StyleStackSectionHeader extends StatelessWidget {
  const StyleStackSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.actionLabel,
  });

  final String title;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignSystem.spacingLg,
        DesignSystem.spacingMd,
        DesignSystem.spacingLg,
        DesignSystem.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (action != null && actionLabel != null)
            TextButton(onPressed: action, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class StyleStackInfoBanner extends StatelessWidget {
  const StyleStackInfoBanner({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.type = _BannerType.info,
  });

  final IconData icon;
  final String title;
  final String? message;
  final _BannerType type;

  Color _getBackgroundColor() => switch (type) {
    _BannerType.info => DesignSystem.secondary.withOpacity(0.1),
    _BannerType.success => DesignSystem.success.withOpacity(0.1),
    _BannerType.warning => DesignSystem.warning.withOpacity(0.1),
    _BannerType.error => DesignSystem.error.withOpacity(0.1),
  };

  Color _getIconColor() => switch (type) {
    _BannerType.info => DesignSystem.primary,
    _BannerType.success => DesignSystem.success,
    _BannerType.warning => DesignSystem.warning,
    _BannerType.error => DesignSystem.error,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignSystem.spacingMd),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
        border: Border.all(color: _getIconColor().withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _getIconColor(), size: DesignSystem.iconSizeMedium),
          const SizedBox(width: DesignSystem.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: DesignSystem.textPrimary,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: DesignSystem.spacingSm),
                  Text(
                    message!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DesignSystem.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StyleStackColorPicker extends StatefulWidget {
  const StyleStackColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    this.enabled = true,
  });

  final String? selectedColor;
  final ValueChanged<String> onColorSelected;
  final bool enabled;

  @override
  State<StyleStackColorPicker> createState() => _StyleStackColorPickerState();
}

class _StyleStackColorPickerState extends State<StyleStackColorPicker> {
  static const List<String> _colors = [
    'Black',
    'White',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Purple',
    'Pink',
    'Brown',
    'Grey',
    'Orange',
    'Beige',
    'Multicolor',
  ];

  Color _getColorFromString(String colorName) {
    final name = colorName.toLowerCase().trim();
    return switch (name) {
      'black' => Colors.black,
      'white' => Colors.grey.shade100,
      'red' => Colors.red.shade400,
      'blue' => Colors.blue.shade400,
      'green' => Colors.green.shade400,
      'yellow' => Colors.amber.shade400,
      'purple' => Colors.purple.shade400,
      'pink' => Colors.pink.shade400,
      'brown' => Colors.brown.shade400,
      'grey' => Colors.grey.shade400,
      'orange' => Colors.orange.shade400,
      'beige' => const Color(0xFFD4A574),
      'multicolor' => DesignSystem.primary,
      _ => DesignSystem.secondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: DesignSystem.spacingMd),
        Wrap(
          spacing: DesignSystem.spacingMd,
          runSpacing: DesignSystem.spacingMd,
          children: _colors.map((color) {
            final isSelected =
                widget.selectedColor?.toLowerCase() == color.toLowerCase();
            return GestureDetector(
              onTap: widget.enabled
                  ? () => widget.onColorSelected(color)
                  : null,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getColorFromString(color),
                  borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
                  border: Border.all(
                    color: isSelected
                        ? DesignSystem.primary
                        : Colors.transparent,
                    width: isSelected ? 3 : 0,
                  ),
                  boxShadow: isSelected
                      ? DesignSystem.shadowMedium
                      : DesignSystem.shadowSoft,
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.check, color: Colors.white, size: 24),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        if (widget.selectedColor != null) ...[
          const SizedBox(height: DesignSystem.spacingMd),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSystem.spacingMd,
              vertical: DesignSystem.spacingSm,
            ),
            decoration: BoxDecoration(
              color: DesignSystem.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
            ),
            child: Text(
              'Selected: ${widget.selectedColor}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DesignSystem.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _BannerType { info, success, warning, error }
