import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../models/onboarding_profile.dart';
import '../providers/onboarding_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.updateDisplayName,
    this.onCompleted,
    super.key,
  });

  final Future<void> Function(String name) updateDisplayName;
  final VoidCallback? onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _questionCount = 8;
  final _pages = PageController();
  final _name = TextEditingController();
  int _step = 0;
  bool _seeded = false;
  String? _gender;
  DateTime? _dateOfBirth;
  String? _bodyType;
  int? _heightCm;
  double _heightPreview = 168;
  final Set<String> _styles = {};
  String? _shoppingFrequency;
  final Set<String> _goals = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final profile = context.read<OnboardingProvider>().profile;
    if (profile != null) {
      _name.text = profile.displayName ?? '';
      _gender = profile.gender;
      _dateOfBirth = profile.dateOfBirth;
      _bodyType = profile.bodyType;
      _heightCm = profile.heightCm;
      _heightPreview = (profile.heightCm ?? 168).toDouble();
      _styles.addAll(profile.stylePreferences);
      _shoppingFrequency = profile.shoppingFrequency;
      _goals.addAll(profile.styleGoals);
    }
    _name.addListener(_refresh);
    _seeded = true;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_refresh);
    _name.dispose();
    _pages.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    0 => _name.text.trim().length >= 2,
    1 => _gender != null,
    2 => _dateOfBirth != null,
    _ => true,
  };

  Future<void> _next() async {
    if (!_canContinue || _step >= _questionCount) return;
    FocusScope.of(context).unfocus();
    await _pages.nextPage(
      duration: DesignSystem.transitionStandard,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    if (_step == 0) return;
    await _pages.previousPage(
      duration: DesignSystem.transitionStandard,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skip() async {
    switch (_step) {
      case 3:
        _bodyType = null;
      case 4:
        _heightCm = null;
      case 5:
        _styles.clear();
      case 6:
        _shoppingFrequency = null;
      case 7:
        _goals.clear();
    }
    setState(() {});
    await _next();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select your date of birth',
    );
    if (selected != null) setState(() => _dateOfBirth = selected);
  }

  void _toggleStyle(String value) {
    const discoveryChoices = {'not_sure', 'explore'};
    setState(() {
      if (_styles.contains(value)) {
        _styles.remove(value);
      } else if (discoveryChoices.contains(value)) {
        _styles
          ..clear()
          ..add(value);
      } else {
        _styles
          ..removeAll(discoveryChoices)
          ..add(value);
      }
    });
  }

  Future<void> _finish() async {
    final provider = context.read<OnboardingProvider>();
    final profile = OnboardingProfile(
      displayName: _name.text.trim(),
      gender: _gender,
      dateOfBirth: _dateOfBirth,
      bodyType: _bodyType,
      heightCm: _heightCm,
      stylePreferences: _styles.toList(growable: false),
      shoppingFrequency: _shoppingFrequency,
      styleGoals: _goals.toList(growable: false),
    );
    final completed = await provider.complete(profile);
    if (!completed || !mounted) return;
    try {
      await widget.updateDisplayName(_name.text.trim());
    } catch (_) {
      // The backend profile is authoritative. A transient Firebase profile
      // update should not force the user through onboarding again.
    }
    if (mounted) widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final onSummary = _step == _questionCount;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      key: const Key('onboarding_back'),
                      tooltip: 'Previous question',
                      onPressed: provider.saving ? null : _back,
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          onSummary
                              ? 'Ready to style'
                              : 'Step ${_step + 1} of 8',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: DesignSystem.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: onSummary ? 1 : (_step + 1) / _questionCount,
                            backgroundColor: DesignSystem.surfaceAlt,
                            color: DesignSystem.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => _step = value),
                children: [
                  _nameCard(),
                  _genderCard(),
                  _birthDateCard(),
                  _bodyTypeCard(),
                  _heightCard(),
                  _styleCard(),
                  _shoppingCard(),
                  _goalsCard(),
                  _summaryCard(provider),
                ],
              ),
            ),
            if (!onSummary)
              _Footer(
                optional: _step >= 3,
                canContinue: _canContinue && !provider.saving,
                onSkip: _skip,
                onContinue: _next,
              ),
          ],
        ),
      ),
    );
  }

  Widget _nameCard() => _QuestionCard(
    icon: Icons.auto_awesome_rounded,
    title: 'Welcome to StyleStack',
    subtitle:
        "Let's set up your personal stylist so every suggestion feels like you.",
    child: TextField(
      key: const Key('onboarding_name'),
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'What should we call you?',
        hintText: 'Your name',
        helperText: "We'll use this to greet you daily",
        errorText: _name.text.isNotEmpty && _name.text.trim().length < 2
            ? 'Enter at least 2 characters'
            : null,
        prefixIcon: const Icon(Icons.person_outline_rounded),
      ),
      onSubmitted: (_) => _next(),
    ),
  );

  Widget _genderCard() => _QuestionCard(
    icon: Icons.person_search_outlined,
    title: 'How do you identify?',
    subtitle:
        'This helps us suggest relevant silhouettes while keeping your choices personal.',
    child: _ChoiceWrap(
      values: const {
        'woman': ('Woman', Icons.female_rounded),
        'man': ('Man', Icons.male_rounded),
        'non_binary': ('Non-binary', Icons.diversity_1_outlined),
        'prefer_not_to_say': ('Prefer not to say', Icons.privacy_tip_outlined),
      },
      selected: _gender == null ? const {} : {_gender!},
      onTap: (value) => setState(() => _gender = value),
    ),
  );

  Widget _birthDateCard() => _QuestionCard(
    icon: Icons.cake_outlined,
    title: 'When were you born?',
    subtitle:
        'This helps tailor style context across life stages. We keep it private.',
    child: _ChoiceSurface(
      key: const Key('onboarding_dob'),
      selected: _dateOfBirth != null,
      onTap: _pickBirthDate,
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _dateOfBirth == null
                  ? 'Select date of birth'
                  : _formatDate(_dateOfBirth!),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );

  Widget _bodyTypeCard() => _QuestionCard(
    icon: Icons.accessibility_new_rounded,
    title: 'Tell us about your body type',
    subtitle:
        "This can improve fit suggestions, and it's completely okay not to be sure.",
    optional: true,
    child: _ChoiceWrap(
      values: const {
        'slim': ('Slim', Icons.straighten_rounded),
        'average': ('Average', Icons.person_outline),
        'athletic': ('Athletic', Icons.fitness_center_rounded),
        'curvy': ('Curvy', Icons.favorite_border_rounded),
        'plus': ('Plus', Icons.add_circle_outline_rounded),
        'not_sure': ('Not sure', Icons.help_outline_rounded),
      },
      selected: _bodyType == null ? const {} : {_bodyType!},
      onTap: (value) => setState(() => _bodyType = value),
    ),
  );

  Widget _heightCard() => _QuestionCard(
    icon: Icons.height_rounded,
    title: 'How tall are you?',
    subtitle: 'Helps us consider garment lengths and proportions.',
    optional: true,
    child: Column(
      children: [
        Text(
          _heightCm == null
              ? 'Move the slider to add height'
              : _heightLabel(_heightCm!),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _heightCm == null
                ? DesignSystem.textSecondary
                : DesignSystem.primary,
          ),
        ),
        const SizedBox(height: 16),
        Slider(
          key: const Key('onboarding_height'),
          min: 122,
          max: 213,
          divisions: 91,
          value: _heightPreview,
          label: _heightLabel(_heightPreview.round()),
          onChanged: (value) => setState(() {
            _heightPreview = value;
            _heightCm = value.round();
          }),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text("4'0\""), Text("7'0\"")],
        ),
      ],
    ),
  );

  Widget _styleCard() => _QuestionCard(
    icon: Icons.checkroom_rounded,
    title: "What's your style vibe?",
    subtitle:
        "Pick any that feel right. If you're unsure, we'll learn from what you wear.",
    optional: true,
    child: _ChoiceWrap(
      values: const {
        'formal': ('Formal', Icons.business_center_outlined),
        'office': ('Office', Icons.work_outline_rounded),
        'casual': ('Casual', Icons.weekend_outlined),
        'sporty': ('Sporty', Icons.directions_run_rounded),
        'trendy': ('Trendy', Icons.bolt_rounded),
        'ethnic': ('Ethnic', Icons.local_florist_outlined),
        'minimal': ('Minimal', Icons.remove_rounded),
        'bohemian': ('Bohemian', Icons.filter_vintage_outlined),
        'glam': ('Glam', Icons.diamond_outlined),
        'not_sure': ('Not sure yet', Icons.help_outline_rounded),
        'explore': ('Let me explore', Icons.explore_outlined),
      },
      selected: _styles,
      onTap: _toggleStyle,
    ),
  );

  Widget _shoppingCard() => _QuestionCard(
    icon: Icons.shopping_bag_outlined,
    title: 'How often do you buy clothes?',
    subtitle: 'This helps us understand your wardrobe refresh cycle.',
    optional: true,
    child: Column(
      children:
          const {
            'every_week': 'Every week',
            'every_month': 'Every month',
            'every_2_3_months': 'Every 2–3 months',
            'every_season': 'Every season',
            'rarely': 'Rarely — only when needed',
          }.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChoiceSurface(
                key: Key('onboarding_choice_${entry.key}'),
                selected: _shoppingFrequency == entry.key,
                onTap: () => setState(() => _shoppingFrequency = entry.key),
                child: Row(
                  children: [
                    Icon(
                      _shoppingFrequency == entry.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            );
          }).toList(),
    ),
  );

  Widget _goalsCard() => _QuestionCard(
    icon: Icons.track_changes_rounded,
    title: 'What brings you to StyleStack?',
    subtitle: 'Choose everything that matters to you right now.',
    optional: true,
    child: Column(
      children:
          const {
            'daily_outfit_ideas': 'Getting daily outfit ideas',
            'organize_wardrobe': 'Organizing my wardrobe',
            'discover_personal_style': 'Discovering my personal style',
            'reduce_decision_fatigue': 'Reducing decision fatigue',
            'shop_less_style_better': 'Shopping less, styling better',
            'outfit_inspiration': 'Getting outfit inspiration',
            'track_what_i_wear': 'Tracking what I wear',
          }.entries.map((entry) {
            final selected = _goals.contains(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChoiceSurface(
                key: Key('onboarding_choice_${entry.key}'),
                selected: selected,
                onTap: () => setState(() {
                  selected ? _goals.remove(entry.key) : _goals.add(entry.key);
                }),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            );
          }).toList(),
    ),
  );

  Widget _summaryCard(OnboardingProvider provider) {
    final styleSummary =
        _styles.isEmpty ||
            _styles.contains('not_sure') ||
            _styles.contains('explore')
        ? "Let's discover your style"
        : _styles.map(_readable).join(', ');
    return _QuestionCard(
      icon: Icons.check_circle_outline_rounded,
      title: "You're all set, ${_name.text.trim()}!",
      subtitle: 'Your personal stylist is ready to learn and evolve with you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryLine(icon: Icons.person_outline, text: _name.text.trim()),
          _SummaryLine(
            icon: Icons.cake_outlined,
            text: _dateOfBirth == null
                ? 'Date of birth not selected'
                : '${_age(_dateOfBirth!)} years old',
          ),
          _SummaryLine(
            icon: Icons.diversity_1_outlined,
            text: _gender == null
                ? 'Identity not selected'
                : _readable(_gender!),
          ),
          _SummaryLine(icon: Icons.checkroom_outlined, text: styleSummary),
          const _SummaryLine(
            icon: Icons.auto_awesome_outlined,
            text: "We'll learn from every choice",
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 12),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DesignSystem.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('onboarding_finish'),
            style: FilledButton.styleFrom(backgroundColor: DesignSystem.cta),
            onPressed: provider.saving ? null : _finish,
            icon: provider.saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(
              provider.saving
                  ? 'Building your profile…'
                  : 'Show my first outfit',
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')} / '
      '${value.month.toString().padLeft(2, '0')} / ${value.year}';

  static int _age(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static String _heightLabel(int centimeters) {
    final totalInches = (centimeters / 2.54).round();
    return '${totalInches ~/ 12} ft ${totalInches % 12} in · $centimeters cm';
  }

  static String _readable(String value) => value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.optional = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool optional;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Material(
          color: DesignSystem.surface,
          borderRadius: BorderRadius.circular(DesignSystem.radiusXxl),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusXxl),
            side: const BorderSide(color: DesignSystem.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: DesignSystem.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: DesignSystem.primary, size: 29),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    if (optional)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: DesignSystem.surfaceAlt,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text('Optional'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: DesignSystem.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 26),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.optional,
    required this.canContinue,
    required this.onSkip,
    required this.onContinue,
  });

  final bool optional;
  final bool canContinue;
  final VoidCallback onSkip;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Material(
    color: DesignSystem.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          children: [
            if (optional) ...[
              TextButton(
                key: const Key('onboarding_skip'),
                onPressed: onSkip,
                child: const Text('Skip'),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton.icon(
                key: const Key('onboarding_continue'),
                onPressed: canContinue ? onContinue : null,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.onTap,
  });

  final Map<String, (String, IconData)> values;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: values.entries.map((entry) {
          return SizedBox(
            width: width,
            child: _ChoiceSurface(
              key: Key('onboarding_choice_${entry.key}'),
              selected: selected.contains(entry.key),
              onTap: () => onTap(entry.key),
              child: Column(
                children: [
                  Icon(entry.value.$2, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    entry.value.$1,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

class _ChoiceSurface extends StatelessWidget {
  const _ChoiceSurface({
    required this.selected,
    required this.onTap,
    required this.child,
    super.key,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: DesignSystem.transitionQuick,
    decoration: BoxDecoration(
      color: selected
          ? DesignSystem.primary.withValues(alpha: .09)
          : DesignSystem.surfaceAlt,
      borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
      border: Border.all(
        color: selected ? DesignSystem.primary : DesignSystem.border,
        width: selected ? 2 : 1,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: IconTheme(
            data: IconThemeData(
              color: selected
                  ? DesignSystem.primary
                  : DesignSystem.textSecondary,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: DesignSystem.primary, size: 21),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
