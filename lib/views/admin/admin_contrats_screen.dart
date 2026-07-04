import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/assurance_model.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminContratsScreen extends ConsumerStatefulWidget {
  const AdminContratsScreen({super.key});

  @override
  ConsumerState<AdminContratsScreen> createState() => _AdminContratsScreenState();
}

class _AdminContratsScreenState extends ConsumerState<AdminContratsScreen> {
  StatutContrat? _filtre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminViewModelProvider.notifier).loadContrats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);

    ref.listen(adminViewModelProvider, (_, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: AppColors.success),
        );
        ref.read(adminViewModelProvider.notifier).clearMessages();
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
        ref.read(adminViewModelProvider.notifier).clearMessages();
      }
    });

    final contrats = _filtre == null
        ? state.contrats
        : state.contrats.where((c) => c.statut == _filtre).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrats assurance'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminViewModelProvider.notifier).loadContrats(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _FiltreChips(
                  selected: _filtre,
                  total: state.contrats.length,
                  counts: _countsByStatut(state.contrats),
                  onSelect: (s) => setState(() => _filtre = s),
                ),
                Expanded(
                  child: contrats.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 64, color: AppColors.textSecondary),
                              SizedBox(height: 12),
                              Text('Aucun contrat', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => ref.read(adminViewModelProvider.notifier).loadContrats(),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: contrats.length,
                            itemBuilder: (context, i) {
                              final contrat = contrats[i];
                              final user = state.users
                                  .where((u) => u.id == contrat.userId)
                                  .firstOrNull;
                              final userName = user != null
                                  ? user.nom.isNotEmpty ? user.nom : user.email
                                  : contrat.userId;
                              return _ContratCard(
                                contrat: contrat,
                                userName: userName,
                                onChangeStatut: (s) => _confirmStatut(contrat, s),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Map<StatutContrat, int> _countsByStatut(List<ContratAssuranceModel> all) {
    final map = <StatutContrat, int>{};
    for (final c in all) {
      map[c.statut] = (map[c.statut] ?? 0) + 1;
    }
    return map;
  }

  void _confirmStatut(ContratAssuranceModel contrat, StatutContrat nouveau) {
    if (contrat.statut == nouveau) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le statut ?'),
        content: Text(
          'Passer de « ${_statutLabel(contrat.statut)} » à « ${_statutLabel(nouveau)} » ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _statutColor(nouveau)),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminViewModelProvider.notifier).updateContratStatut(contrat.id, nouveau);
            },
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Filtre chips ──────────────────────────────────────────────────────────────

class _FiltreChips extends StatelessWidget {
  final StatutContrat? selected;
  final int total;
  final Map<StatutContrat, int> counts;
  final ValueChanged<StatutContrat?> onSelect;

  const _FiltreChips({
    required this.selected,
    required this.total,
    required this.counts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _Chip(
            label: 'Tous ($total)',
            color: AppColors.primary,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          ...StatutContrat.values.map((s) {
            final count = counts[s] ?? 0;
            return _Chip(
              label: '${_statutLabel(s)} ($count)',
              color: _statutColor(s),
              selected: selected == s,
              onTap: () => onSelect(s == selected ? null : s),
            );
          }),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color.withValues(alpha: 0.2),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: selected ? color : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
        side: BorderSide(color: selected ? color : Colors.grey.shade300),
      ),
    );
  }
}

// ── Carte contrat ─────────────────────────────────────────────────────────────

class _ContratCard extends StatelessWidget {
  final ContratAssuranceModel contrat;
  final String userName;
  final ValueChanged<StatutContrat> onChangeStatut;
  const _ContratCard({required this.contrat, required this.userName, required this.onChangeStatut});

  @override
  Widget build(BuildContext context) {
    final color = _statutColor(contrat.statut);
    final fmt = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : nom utilisateur + badge statut
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatutBadge(statut: contrat.statut),
              ],
            ),
            const SizedBox(height: 10),

            // Infos
            _InfoRow(icon: Icons.location_on_outlined, label: 'Zone', value: contrat.zoneRisque),
            _InfoRow(icon: Icons.category_outlined, label: 'Produit', value: contrat.produitId),
            _InfoRow(
              icon: Icons.payments_outlined,
              label: 'Prime mensuelle',
              value: '${contrat.primeMensuelle.toStringAsFixed(0)} FCFA',
            ),
            _InfoRow(icon: Icons.calendar_today_outlined, label: 'Depuis', value: fmt.format(contrat.dateDebut)),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Actions de changement de statut
            Row(
              children: [
                const Text('Changer statut :', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: StatutContrat.values
                          .where((s) => s != contrat.statut)
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () => onChangeStatut(s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statutColor(s).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _statutColor(s).withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      _statutLabel(s),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _statutColor(s),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('$label : ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final StatutContrat statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final color = _statutColor(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _statutLabel(statut),
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Helpers partagés ──────────────────────────────────────────────────────────

String _statutLabel(StatutContrat s) => switch (s) {
      StatutContrat.soumis   => 'Soumis',
      StatutContrat.actif    => 'Actif',
      StatutContrat.expire   => 'Expiré',
      StatutContrat.sinistre => 'Sinistre',
    };

Color _statutColor(StatutContrat s) => switch (s) {
      StatutContrat.soumis   => const Color(0xFFF59E0B),
      StatutContrat.actif    => AppColors.success,
      StatutContrat.expire   => AppColors.textSecondary,
      StatutContrat.sinistre => AppColors.error,
    };
