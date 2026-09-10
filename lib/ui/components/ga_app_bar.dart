import 'package:flutter/material.dart';

/// AppBar du design system : titre Sora (via `textTheme.headlineSmall`),
/// transparente par défaut, filet optionnel sous la barre.
class GaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GaAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.transparent = true,
    this.showDivider = false,
    this.centerTitle = false,
  });

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool transparent;
  final bool showDivider;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(showDivider ? 57 : 56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor:
          transparent ? Colors.transparent : theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      titleSpacing: 4,
      title: titleWidget ??
          (title == null
              ? null
              : Text(title!, style: theme.textTheme.headlineSmall)),
      actions: actions,
      bottom: showDivider
          ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                  height: 1, thickness: 1, color: theme.colorScheme.outline),
            )
          : null,
    );
  }
}
