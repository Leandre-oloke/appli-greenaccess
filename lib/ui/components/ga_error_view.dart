import 'package:flutter/material.dart';

import '../../utils/error_mapper.dart';
import 'ga_buttons.dart';
import 'ga_info_banner.dart';

/// Affichage d'erreur unifié : traduit [error] via [mapErrorToMessage] et
/// l'affiche dans un [GaInfoBanner], avec un bouton « Réessayer » optionnel.
///
/// Remplace l'affichage de `error.toString()` brut dans les écrans dont le
/// ViewModel expose encore une erreur technique non traduite.
class GaErrorView extends StatelessWidget {
  const GaErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
  });

  final Object error;
  final VoidCallback? onRetry;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return GaInfoBanner(
      kind: GaBannerKind.error,
      title: title,
      message: mapErrorToMessage(error),
      action: onRetry == null
          ? null
          : GaSecondaryButton.ghost(label: 'Réessayer', onPressed: onRetry),
    );
  }
}
