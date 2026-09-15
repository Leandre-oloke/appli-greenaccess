import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/user_data_export_model.dart';
import '../repositories/export_repository.dart';
import '../utils/export_formatters.dart';

class ExportState {
  final bool isLoading;
  final String? error;

  const ExportState({this.isLoading = false, this.error});

  ExportState copyWith({bool? isLoading, String? error}) {
    return ExportState(isLoading: isLoading ?? this.isLoading, error: error);
  }
}

/// Orchestre l'export RGPD (J3.4-J3.5) : collecte via [ExportRepository],
/// génération PDF/CSV via `lib/utils/export_formatters.dart`, puis partage/
/// téléchargement du fichier choisi par l'utilisateur.
class ExportViewModel extends StateNotifier<ExportState> {
  final ExportRepository _repository;

  ExportViewModel(this._repository) : super(const ExportState());

  Future<UserDataExportModel?> _collect(String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _repository.exportUserData(userId);
      state = state.copyWith(isLoading: false);
      return data;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Export impossible. Réessayez.');
      return null;
    }
  }

  Future<void> exportAsPdf(String userId) async {
    final data = await _collect(userId);
    if (data == null) return;
    final bytes = await buildExportPdf(data);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'greenaccess_mes_donnees_${_todayStamp()}.pdf',
    );
  }

  Future<void> exportAsCsv(String userId) async {
    final data = await _collect(userId);
    if (data == null) return;
    final csv = buildExportCsv(data);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name: 'greenaccess_mes_donnees_${_todayStamp()}.csv',
      ),
    ]);
  }

  String _todayStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }
}

final exportViewModelProvider = StateNotifierProvider<ExportViewModel, ExportState>(
  (ref) => ExportViewModel(ExportRepository()),
);
