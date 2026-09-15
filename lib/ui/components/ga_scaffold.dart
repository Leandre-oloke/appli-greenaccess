import 'package:flutter/material.dart';

import '../tokens/ga_breakpoints.dart';
import '../tokens/ga_spacing.dart';

/// Coquille de page du design system.
///
/// - fond du thème,
/// - largeur de contenu bornée et centrée (utile sur Web),
/// - gestion de l'inset clavier,
/// - `RefreshIndicator` optionnel quand `scrollable`.
class GaScaffold extends StatelessWidget {
  const GaScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.header,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.symmetric(horizontal: GaSpacing.screenH),
    this.scrollable = false,
    this.onRefresh,
    this.maxContentWidth = GaBreakpoints.maxContent,
    this.extendBodyBehindAppBar = false,
    this.safeTop = true,
    this.safeBottom = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;

  /// Bandeau (ex. [GaGradientHeader]) affiché juste sous l'AppBar, hors padding.
  final Widget? header;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final Future<void> Function()? onRefresh;
  final double maxContentWidth;
  final bool extendBodyBehindAppBar;
  final bool safeTop;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(padding: padding, child: content),
      ),
    );

    if (scrollable) {
      content = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: content,
      );
      if (onRefresh != null) {
        content = RefreshIndicator(onRefresh: onRefresh!, child: content);
      }
    }

    if (header != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header!,
          Expanded(child: content),
        ],
      );
    }

    content = SafeArea(top: safeTop, bottom: safeBottom, child: content);

    return Scaffold(
      appBar: appBar,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: content,
    );
  }
}
