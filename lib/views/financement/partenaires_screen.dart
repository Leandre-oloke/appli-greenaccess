import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PartenairesScreen extends StatefulWidget {
  const PartenairesScreen({super.key});

  @override
  State<PartenairesScreen> createState() => _PartenairesScreenState();
}

class _PartenairesScreenState extends State<PartenairesScreen> {
  String _filter = 'Tous';

  static const _categories = ['Tous', 'Banque développement', 'Microfinance', 'Fonds climatique'];

  static const _partenaires = [
    _Partenaire(
      nom: 'AFD – Agence Française de Développement',
      type: 'Banque développement',
      pays: ['Sénégal', 'Bénin', 'Côte d\'Ivoire', 'Mali', 'Burkina Faso'],
      description: 'Financements de projets verts, prêts bonifiés pour agriculture durable et énergie renouvelable.',
      montantMin: 5000000, montantMax: 50000000,
      contact: 'afd@afd.fr',
      icon: Icons.account_balance,
      color: Color(0xFF1565C0),
    ),
    _Partenaire(
      nom: 'BOAD – Banque Ouest Africaine de Développement',
      type: 'Banque développement',
      pays: ['Sénégal', 'Bénin', 'Côte d\'Ivoire', 'Mali', 'Burkina Faso', 'Niger', 'Togo', 'Guinée'],
      description: 'Financement de projets d\'infrastructure verte et d\'agriculture résiliente en zone UEMOA.',
      montantMin: 10000000, montantMax: 50000000,
      contact: 'info@boad.org',
      icon: Icons.account_balance_wallet,
      color: Color(0xFF2E7D32),
    ),
    _Partenaire(
      nom: 'GCF – Fonds Vert pour le Climat',
      type: 'Fonds climatique',
      pays: ['Sénégal', 'Bénin', 'Côte d\'Ivoire', 'Mali', 'Burkina Faso', 'Niger', 'Togo', 'Guinée'],
      description: 'Subventions et prêts concessionnels pour projets à fort impact climatique. Score ESG ≥ 70 requis.',
      montantMin: 20000000, montantMax: 50000000,
      contact: 'info@greenclimate.fund',
      icon: Icons.eco,
      color: Color(0xFF00695C),
    ),
    _Partenaire(
      nom: 'UEMOA – Fonds d\'Appui à la Finance Inclusive',
      type: 'Fonds climatique',
      pays: ['Sénégal', 'Bénin', 'Côte d\'Ivoire', 'Mali', 'Burkina Faso', 'Niger', 'Togo', 'Guinée'],
      description: 'Programme d\'appui aux PME vertes et petits producteurs alignés avec la taxonomie UEMOA.',
      montantMin: 500000, montantMax: 10000000,
      contact: 'fafi@uemoa.int',
      icon: Icons.public,
      color: Color(0xFF6A1B9A),
    ),
    _Partenaire(
      nom: 'PAMECAS – Microfinance Sénégal',
      type: 'Microfinance',
      pays: ['Sénégal'],
      description: 'Micro-crédits verts pour petits producteurs agricoles et artisans. Taux préférentiels.',
      montantMin: 100000, montantMax: 2000000,
      contact: 'contact@pamecas.sn',
      icon: Icons.savings,
      color: Color(0xFFE65100),
    ),
    _Partenaire(
      nom: 'FCPB – Fonds de la Microfinance Burkina',
      type: 'Microfinance',
      pays: ['Burkina Faso'],
      description: 'Financement de l\'agriculture résiliente et des énergies renouvelables pour ménages ruraux.',
      montantMin: 100000, montantMax: 1500000,
      contact: 'info@fcpb.bf',
      icon: Icons.savings,
      color: Color(0xFFE65100),
    ),
  ];

  List<_Partenaire> get _filtered =>
      _filter == 'Tous' ? _partenaires : _partenaires.where((p) => p.type == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partenaires financiers')),
      body: Column(
        children: [
          _FilterBar(
            categories: _categories,
            selected: _filter,
            onSelect: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _PartenaireCard(partenaire: _filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final void Function(String) onSelect;
  const _FilterBar({required this.categories, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: categories.map((c) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(c),
            selected: selected == c,
            onSelected: (_) => onSelect(c),
            selectedColor: AppColors.secondary.withValues(alpha: 0.2),
            checkmarkColor: AppColors.secondary,
          ),
        )).toList(),
      ),
    );
  }
}

class _PartenaireCard extends StatelessWidget {
  final _Partenaire partenaire;
  const _PartenaireCard({required this.partenaire});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: partenaire.color.withValues(alpha: 0.15),
          child: Icon(partenaire.icon, color: partenaire.color),
        ),
        title: Text(partenaire.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(partenaire.type, style: TextStyle(color: partenaire.color, fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partenaire.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 12),
                _InfoRow(Icons.payments_outlined, 'Montant',
                    '${(partenaire.montantMin / 1000).round()}k – ${(partenaire.montantMax / 1000000).toStringAsFixed(1)}M FCFA'),
                _InfoRow(Icons.location_on_outlined, 'Pays éligibles', partenaire.pays.join(', ')),
                _InfoRow(Icons.email_outlined, 'Contact', partenaire.contact),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Contacter ce partenaire'),
                    style: OutlinedButton.styleFrom(foregroundColor: partenaire.color, side: BorderSide(color: partenaire.color)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('$label : ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        ],
      ),
    );
  }
}

class _Partenaire {
  final String nom, type, contact, description;
  final List<String> pays;
  final double montantMin, montantMax;
  final IconData icon;
  final Color color;
  const _Partenaire({
    required this.nom, required this.type, required this.contact, required this.description,
    required this.pays, required this.montantMin, required this.montantMax,
    required this.icon, required this.color,
  });
}
