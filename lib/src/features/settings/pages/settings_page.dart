import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';
import '../../auth/models/settings_data.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ─── state ─────────────────────────────────────────────────────────────────
  bool _loadingData = true;
  String? _loadError;
  SettingsData? _data;

  bool _saving = false;
  bool _settingCourse = false;
  String? _saveError;
  String? _saveSuccess;

  final _formKey = GlobalKey<FormState>();

  /// Categories the user has ticked in the UI.
  Set<int> _selectedCategoryIds = {};

  /// Courses that were ALREADY enrolled when the page loaded — locked.
  Set<int> _alreadyEnrolledIds = {};

  /// NEW courses the user is adding in this session.
  Set<int> _newlySelectedIds = {};

  // ─── lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ─── data loading ───────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() {
      _loadingData = true;
      _loadError = null;
    });
    try {
      final data = await widget.authController.loadSettings();
      if (!mounted) return;
      setState(() {
        _data = data;
        _populateForm(data);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  void _populateForm(SettingsData data) {
    final u = data.userInfo;
    _selectedCategoryIds = u.selectedCategoryIds.toSet();
    _alreadyEnrolledIds = u.selectedCourseIds.toSet();
    _newlySelectedIds = {};
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  /// All course IDs that are selected (locked + newly chosen).
  Set<int> get _allSelectedCourseIds =>
      _alreadyEnrolledIds.union(_newlySelectedIds);

  /// How many NEW paid course slots are being added.
  int get _newPaidCount {
    final oldPaid = (_alreadyEnrolledIds.length - 1).clamp(0, 999);
    final newTotal = _allSelectedCourseIds.length;
    final newPaid = (newTotal - 1).clamp(0, 999);
    return (newPaid - oldPaid).clamp(0, 999);
  }

  int get _coinCost => _newPaidCount * (_data?.additionalCourseCost ?? 500);

  int get _userCoins =>
      widget.authController.user?.coins ?? _data?.userInfo.coins ?? 0;

  bool get _canAfford => _coinCost == 0 || _userCoins >= _coinCost;

  String _categorySummary(SettingsData data) {
    if (_selectedCategoryIds.isEmpty) {
      return 'No category selected';
    }

    final names = data.categories
        .where((cat) => _selectedCategoryIds.contains(cat.id))
        .map((cat) => cat.name)
        .toList();

    if (names.length <= 2) {
      return names.join(', ');
    }
    return '${names.take(2).join(', ')} +${names.length - 2} more';
  }

  String _courseSummary(SettingsData data) {
    final total = _allSelectedCourseIds.length;
    if (total == 0) {
      return 'No course selected';
    }

    final names = <String>[];
    for (final cat in data.categories) {
      for (final course in cat.courses) {
        if (_allSelectedCourseIds.contains(course.id)) {
          names.add(course.name);
        }
      }
    }

    if (names.length <= 2) {
      return names.join(', ');
    }
    return '${names.take(2).join(', ')} +${names.length - 2} more';
  }

  Future<void> _openCategoryPicker(SettingsData data) async {
    final tempSelected = Set<int>.from(_selectedCategoryIds);
    String query = '';

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final q = query.trim().toLowerCase();
            final filtered = data.categories.where((cat) {
              if (q.isEmpty) return true;
              return cat.name.toLowerCase().contains(q);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Categories',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search categories',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final cat = filtered[index];
                          final selected = tempSelected.contains(cat.id);
                          final hasLocked = cat.courses.any(
                            (c) => _alreadyEnrolledIds.contains(c.id),
                          );
                          final disableUnselect = selected && hasLocked;

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selected,
                            dense: true,
                            title: Text(cat.name),
                            subtitle: disableUnselect
                                ? const Text('Contains enrolled course')
                                : null,
                            secondary: disableUnselect
                                ? const Icon(
                                    Icons.lock_rounded,
                                    size: 18,
                                    color: Color(0xFF22C55E),
                                  )
                                : null,
                            onChanged: disableUnselect
                                ? null
                                : (value) {
                                    setModalState(() {
                                      if (value == true) {
                                        tempSelected.add(cat.id);
                                      } else {
                                        tempSelected.remove(cat.id);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (applied != true || !mounted) {
      return;
    }

    final allowedCourseIds = data.categories
        .where((cat) => tempSelected.contains(cat.id))
        .expand((cat) => cat.courses)
        .map((course) => course.id)
        .toSet();

    setState(() {
      _selectedCategoryIds = tempSelected;
      _newlySelectedIds.removeWhere((id) => !allowedCourseIds.contains(id));
    });
  }

  Future<void> _openCoursePicker(SettingsData data) async {
    if (_selectedCategoryIds.isEmpty) {
      setState(() {
        _saveError = 'Select categories first, then choose courses.';
      });
      return;
    }

    final visibleCourses = data.categories
        .where((cat) => _selectedCategoryIds.contains(cat.id))
        .expand((cat) => cat.courses)
        .toList();
    final courseCategoryName = <int, String>{
      for (final cat in data.categories)
        for (final course in cat.courses) course.id: cat.name,
    };
    final tempNewlySelected = Set<int>.from(_newlySelectedIds);
    String query = '';

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final q = query.trim().toLowerCase();
            final filtered = visibleCourses.where((course) {
              if (q.isEmpty) return true;
              final categoryName = (courseCategoryName[course.id] ?? '')
                  .toLowerCase();
              return course.name.toLowerCase().contains(q) ||
                  categoryName.contains(q);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Courses',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search courses',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final course = filtered[index];
                          final isEnrolled = _alreadyEnrolledIds.contains(
                            course.id,
                          );
                          final selected =
                              isEnrolled ||
                              tempNewlySelected.contains(course.id);

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: selected,
                            title: Text(course.name),
                            subtitle: Text(
                              isEnrolled
                                  ? 'Already enrolled'
                                  : (courseCategoryName[course.id] ?? ''),
                              style: TextStyle(
                                color: isEnrolled
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                            secondary: isEnrolled
                                ? const Icon(
                                    Icons.lock_rounded,
                                    size: 18,
                                    color: Color(0xFF22C55E),
                                  )
                                : null,
                            onChanged: isEnrolled
                                ? null
                                : (value) {
                                    setModalState(() {
                                      if (value == true) {
                                        tempNewlySelected.add(course.id);
                                      } else {
                                        tempNewlySelected.remove(course.id);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (applied != true || !mounted) {
      return;
    }

    setState(() {
      _newlySelectedIds = tempNewlySelected;
    });
  }

  // ─── actions ────────────────────────────────────────────────────────────────
  Future<void> _setActiveCourse(int courseId) async {
    if (_settingCourse) return;
    setState(() => _settingCourse = true);
    try {
      final ok = await widget.authController.setCurrentCourse(courseId);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Active course updated.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.authController.errorMessage ?? 'Failed to update course.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _settingCourse = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryIds.isEmpty) {
      setState(() => _saveError = 'Please select at least one category.');
      return;
    }
    if (_allSelectedCourseIds.isEmpty) {
      setState(() => _saveError = 'Please select at least one course.');
      return;
    }
    if (!_canAfford) {
      setState(
        () => _saveError = 'Not enough coins. You need $_coinCost coins.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
      _saveSuccess = null;
    });

    try {
      // Auto-include categories of already-enrolled locked courses.
      final effectiveCategoryIds = Set<int>.from(_selectedCategoryIds);
      if (_data != null) {
        for (final cat in _data!.categories) {
          for (final course in cat.courses) {
            if (_alreadyEnrolledIds.contains(course.id)) {
              effectiveCategoryIds.add(cat.id);
            }
          }
        }
      }

      final ok = await widget.authController.updateSettings(
        categoryIds: effectiveCategoryIds.toList(),
        courseIds: _allSelectedCourseIds.toList(),
      );

      if (!mounted) return;

      if (ok) {
        // Refresh local data so locked set is updated.
        await _loadData();
        if (mounted) {
          setState(() => _saveSuccess = 'Settings saved successfully!');
        }
      } else {
        setState(
          () => _saveError =
              widget.authController.errorMessage ?? 'Failed to save.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const AppPageShell(
        maxWidth: 720,
        children: [
          AppHeroBanner(
            icon: Icons.settings_rounded,
            title: 'Account Settings',
            subtitle: 'Loading your categories, courses, and preferences.',
            colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
          ),
          SizedBox(height: 16),
          AppSurfaceCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      );
    }

    if (_loadError != null) {
      return AppPageShell(
        maxWidth: 720,
        children: [
          const AppHeroBanner(
            icon: Icons.settings_rounded,
            title: 'Account Settings',
            subtitle: 'We could not load your settings right now.',
            colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
          ),
          const SizedBox(height: 16),
          AppSurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final data = _data!;
    final user = widget.authController.user;
    final enrolledCourseNames = <int, String>{};
    for (final cat in data.categories) {
      for (final c in cat.courses) {
        enrolledCourseNames[c.id] = c.name;
      }
    }

    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final currentCourseId =
            widget.authController.user?.currentCourseId ??
            data.userInfo.currentCourseId;

        return RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── header ────────────────────────────────────────────────
                    const AppHeroBanner(
                      icon: Icons.settings_rounded,
                      title: 'Account Settings',
                      subtitle:
                          'Manage your categories, courses, and preferences',
                      colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
                    ),
                    const SizedBox(height: 16),

                    // ── info chips ────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.person_rounded,
                            color: const Color(0xFF1E3A8A),
                            label: 'Username',
                            value: user?.name ?? data.userInfo.name,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.monetization_on_rounded,
                            color: const Color(0xFFD97706),
                            label: 'Coins',
                            value:
                                '${widget.authController.user?.coins ?? data.userInfo.coins}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.book_rounded,
                            color: const Color(0xFF7C3AED),
                            label: 'Active Course',
                            value:
                                widget.authController.user?.currentCourseName ??
                                (currentCourseId != null
                                    ? enrolledCourseNames[currentCourseId] ??
                                          'N/A'
                                    : 'None'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── select active course ───────────────────────────────────
                    if (_alreadyEnrolledIds.length > 1) ...[
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardTitle(
                              icon: Icons.swap_horiz_rounded,
                              title: 'Select Active Course',
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Choose which enrolled course is active for practice and tests.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_settingCourse)
                              const Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else
                              ...(_alreadyEnrolledIds.map((courseId) {
                                final name =
                                    enrolledCourseNames[courseId] ??
                                    'Course $courseId';
                                final isActive = currentCourseId == courseId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _settingCourse || isActive
                                        ? null
                                        : () => _setActiveCourse(courseId),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? const Color(0xFFEFF6FF)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isActive
                                              ? const Color(0xFF93C5FD)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isActive
                                                ? Icons
                                                      .radio_button_checked_rounded
                                                : Icons
                                                      .radio_button_off_rounded,
                                            color: isActive
                                                ? const Color(0xFF1E3A8A)
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(name),
                                                if (isActive)
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      top: 2,
                                                    ),
                                                    child: Text(
                                                      'Currently active',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF16A34A,
                                                        ),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              })),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── personal info + courses form ──────────────────────────
                    _Card(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardTitle(
                              icon: Icons.edit_note_rounded,
                              title: 'Course Preferences',
                            ),
                            const SizedBox(height: 16),
                            const SizedBox(height: 20),

                            // ── categories ───────────────────────────────────
                            _SelectionTile(
                              icon: Icons.category_rounded,
                              title: 'Categories',
                              subtitle: _categorySummary(data),
                              countLabel:
                                  '${_selectedCategoryIds.length}/${data.categories.length}',
                              onTap: () => _openCategoryPicker(data),
                            ),
                            const SizedBox(height: 12),

                            // ── courses ──────────────────────────────────────
                            _SelectionTile(
                              icon: Icons.menu_book_rounded,
                              title: 'Courses',
                              subtitle: _courseSummary(data),
                              countLabel:
                                  '${_allSelectedCourseIds.length} selected',
                              onTap: () => _openCoursePicker(data),
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                const Text(
                                  'Courses',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.monetization_on_rounded,
                                        size: 14,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '1st course free · +${data.additionalCourseCost} coins each',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF92400E),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Already-enrolled courses are locked. Add more courses from the categories above.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ── coin cost summary ─────────────────────────────
                            if (_coinCost > 0) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _canAfford
                                      ? const Color(0xFFFFFBEB)
                                      : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _canAfford
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFF87171),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _canAfford
                                          ? Icons.monetization_on_rounded
                                          : Icons.warning_rounded,
                                      color: _canAfford
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFEF4444),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _canAfford
                                          ? Text(
                                              'Adding $_newPaidCount course(s) will cost $_coinCost coins. '
                                              'You have ${widget.authController.user?.coins ?? data.userInfo.coins} coins.',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF92400E),
                                              ),
                                            )
                                          : Text(
                                              'Not enough coins! You need $_coinCost coins but have '
                                              '${widget.authController.user?.coins ?? data.userInfo.coins} coins.',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFFB91C1C),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ── feedback messages ─────────────────────────────
                            if (_saveError != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFF87171),
                                  ),
                                ),
                                child: Text(
                                  _saveError!,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                            if (_saveSuccess != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF86EFAC),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF16A34A),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _saveSuccess!,
                                      style: const TextStyle(
                                        color: Color(0xFF166534),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),

                            // ── save button ───────────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(
                                  _saving ? 'Saving...' : 'Save Settings',
                                ),
                                onPressed: _saving ? null : _saveSettings,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── small reusable widgets ──────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(padding: const EdgeInsets.all(16), child: child);
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.countLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String countLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    countLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
