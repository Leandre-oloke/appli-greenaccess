import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../core/constants/app_colors.dart';
import '../../models/course_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/formation_viewmodel.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String courseId;
  const QuizScreen({super.key, required this.courseId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with SingleTickerProviderStateMixin {
  List<QuizQuestion> _questions = [];
  final List<int?> _answers = [];
  int _current = 0;
  bool _submitted = false;
  bool _loading = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_animCtrl);
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final uid = ref.read(authViewModelProvider).user?.id ?? '';
    final questions = await ref.read(formationViewModelProvider(uid).notifier).loadQuiz(widget.courseId);
    if (mounted) {
      setState(() {
        _questions = questions;
        _answers.addAll(List.filled(questions.length, null));
        _loading = false;
      });
      _animCtrl.forward();
    }
  }

  void _selectAnswer(int idx) {
    if (_submitted) return;
    setState(() => _answers[_current] = idx);
  }

  void _next() {
    if (_current < _questions.length - 1) {
      _animCtrl.reverse().then((_) {
        setState(() => _current++);
        _animCtrl.forward();
      });
    } else {
      _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    setState(() => _submitted = true);
    final uid = ref.read(authViewModelProvider).user?.id ?? '';
    await ref.read(formationViewModelProvider(uid).notifier).submitQuiz(
          widget.courseId,
          _answers.map((a) => a ?? -1).toList(),
          _questions,
        );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  int get _score {
    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i].correctIndex) correct++;
    }
    return correct;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('Aucune question disponible pour ce cours.')),
      );
    }
    if (_submitted) return _ResultPage(score: _score, total: _questions.length, onBack: () => context.pop());

    final q = _questions[_current];
    final progress = (_current + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Question ${_current + 1} / ${_questions.length}'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          LinearPercentIndicator(
            lineHeight: 6,
            percent: progress,
            backgroundColor: AppColors.divider,
            progressColor: AppColors.primary,
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _QuestionCard(question: q),
                    const SizedBox(height: 24),
                    ...List.generate(
                      q.options.length,
                      (i) => _OptionTile(
                        label: q.options[i],
                        index: i,
                        selected: _answers[_current] == i,
                        onTap: () => _selectAnswer(i),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _answers[_current] == null ? null : _next,
                      child: Text(_current == _questions.length - 1 ? 'Terminer' : 'Suivant'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuizQuestion question;
  const _QuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (question.type == 'vrai_faux')
              const Chip(
                label: Text('Vrai / Faux'),
                backgroundColor: Color(0xFFE3F2FD),
              ),
            const SizedBox(height: 8),
            Text(
              question.question,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.label, required this.index, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8)]
              : [],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: selected ? Colors.white : AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                String.fromCharCode(65 + index),
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPage extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onBack;
  const _ResultPage({required this.score, required this.total, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (score / total * 100).round() : 0;
    final passed = pct >= 70;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: (passed ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                child: Icon(
                  passed ? Icons.emoji_events : Icons.refresh,
                  size: 60,
                  color: passed ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                passed ? 'Félicitations !' : 'Continue tes efforts !',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '$score / $total correctes  ·  $pct%',
                style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (passed)
                const Text(
                  'XP et badge ajoutés à ton profil !',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.success),
                )
              else
                const Text(
                  'Score requis : 70%. Rejoue le quiz pour améliorer ton score.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.error),
                ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: onBack,
                child: const Text('Retour au cours'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
