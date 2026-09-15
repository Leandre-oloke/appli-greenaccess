import 'package:flutter/widgets.dart';

/// Rayons d'arrondi du design system.
abstract final class GaRadii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16; // inputs
  static const double lg = 20; // cartes
  static const double xl = 28; // grandes cartes, bandeaux
  static const double pill = 999; // boutons, pills

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));

  /// Bandeau : coins bas arrondis uniquement.
  static const BorderRadius brHeaderBottom = BorderRadius.only(
    bottomLeft: Radius.circular(xl),
    bottomRight: Radius.circular(xl),
  );

  /// Feuille modale : coins haut arrondis uniquement.
  static const BorderRadius brSheetTop = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );
}
