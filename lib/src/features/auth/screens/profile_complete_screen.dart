import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../auth_controller.dart';
import '../../dashboard/student_dashboard_screen.dart';
import '../models/profile_bootstrap.dart';

class ProfileCompleteScreen extends StatefulWidget {
  const ProfileCompleteScreen({
    super.key,
    required this.authController,
    this.prefilledReferralCode,
  });

  final AuthController authController;
  final String? prefilledReferralCode;

  @override
  State<ProfileCompleteScreen> createState() => _ProfileCompleteScreenState();
}

class _ProfileCompleteScreenState extends State<ProfileCompleteScreen> {
  static final RegExp _nepaliMobileRegex = RegExp(r'^9[78]\d{8}$');

  static const List<_LabelValueOption> _lastDegreeOptions = [
    _LabelValueOption(label: 'SEE/10', value: 'see'),
    _LabelValueOption(label: '+2', value: '+2'),
    _LabelValueOption(label: 'Diploma', value: 'diploma'),
    _LabelValueOption(label: 'Bachelor', value: 'bachelor'),
    _LabelValueOption(label: 'Master', value: 'master'),
    _LabelValueOption(label: 'PhD', value: 'phd'),
  ];

  static const List<String> _districtOptions = [
    'Achham',
    'Arghakhanchi',
    'Baglung',
    'Baitadi',
    'Bajhang',
    'Bajura',
    'Banke',
    'Bara',
    'Bardiya',
    'Bhaktapur',
    'Bhojpur',
    'Chitwan',
    'Dadeldhura',
    'Dailekh',
    'Dang',
    'Darchula',
    'Dhading',
    'Dhankuta',
    'Dhanusha',
    'Dolakha',
    'Dolpa',
    'Doti',
    'Eastern Rukum',
    'Gorkha',
    'Gulmi',
    'Humla',
    'Ilam',
    'Jajarkot',
    'Jhapa',
    'Jumla',
    'Kailali',
    'Kalikot',
    'Kanchanpur',
    'Kapilvastu',
    'Kaski',
    'Kathmandu',
    'Kavrepalanchok',
    'Khotang',
    'Lalitpur',
    'Lamjung',
    'Mahottari',
    'Makwanpur',
    'Manang',
    'Morang',
    'Mugu',
    'Mustang',
    'Myagdi',
    'Nawalpur',
    'Nuwakot',
    'Okhaldhunga',
    'Palpa',
    'Panchthar',
    'Parasi',
    'Parbat',
    'Parsa',
    'Pyuthan',
    'Ramechhap',
    'Rasuwa',
    'Rautahat',
    'Rolpa',
    'Rukum East',
    'Rukum West',
    'Rupandehi',
    'Salyan',
    'Sankhuwasabha',
    'Saptari',
    'Sarlahi',
    'Sindhuli',
    'Sindhupalchok',
    'Siraha',
    'Solukhumbu',
    'Sunsari',
    'Surkhet',
    'Syangja',
    'Tanahun',
    'Taplejung',
    'Tehrathum',
    'Udayapur',
    'Western Rukum',
  ];

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _collegeController = TextEditingController();
  final _referralCodeController = TextEditingController();

  String? _selectedLastDegree;
  String? _selectedDistrict;

  bool _loadingOptions = true;
  String? _loadingError;
  bool _loadingCollegeSuggestions = false;
  Timer? _collegeSearchDebounce;
  List<String> _collegeSuggestions = const [];
  List<ProfileCategory> _categories = const [];
  List<ProfileCourse> _availableCourses = const [];
  int? _selectedCategoryId;
  int? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _referralCodeController.text = widget.prefilledReferralCode ?? '';
    _loadBootstrap();
  }

  @override
  void didUpdateWidget(covariant ProfileCompleteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.prefilledReferralCode ?? '').isNotEmpty &&
        _referralCodeController.text.trim().isEmpty) {
      _referralCodeController.text = widget.prefilledReferralCode!;
    }
  }

  @override
  void dispose() {
    _collegeSearchDebounce?.cancel();
    _phoneController.dispose();
    _dobController.dispose();
    _collegeController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _searchCollegeSuggestions(String query) async {
    _collegeSearchDebounce?.cancel();

    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (mounted) {
        setState(() {
          _collegeSuggestions = const [];
          _loadingCollegeSuggestions = false;
        });
      }
      return;
    }

    _collegeSearchDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingCollegeSuggestions = true;
      });

      try {
        final suggestions = await widget.authController.loadCollegeSuggestions(
          trimmed,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _collegeSuggestions = suggestions;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _collegeSuggestions = const [];
        });
      } finally {
        if (mounted) {
          setState(() {
            _loadingCollegeSuggestions = false;
          });
        }
      }
    });
  }

  Future<void> _loadBootstrap() async {
    setState(() {
      _loadingOptions = true;
      _loadingError = null;
    });

    try {
      final bootstrap = await widget.authController.loadProfileBootstrap();

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = bootstrap.categories;

        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id;
          _availableCourses = _categories.first.courses;
          if (_availableCourses.isNotEmpty) {
            _selectedCourseId = _availableCourses.first.id;
          }
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingOptions = false;
        });
      }
    }
  }

  void _onCategoryChanged(int? categoryId) {
    if (categoryId == null) {
      return;
    }

    final match = _categories.firstWhere(
      (category) => category.id == categoryId,
      orElse: () => const ProfileCategory(id: 0, name: '', courses: []),
    );

    setState(() {
      _selectedCategoryId = categoryId;
      _availableCourses = match.courses;
      _selectedCourseId = _availableCourses.isNotEmpty
          ? _availableCourses.first.id
          : null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null || _selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select category and course.')),
      );
      return;
    }

    final success = await widget.authController.completeProfile(
      phone: _phoneController.text.trim(),
      dateOfBirth: _dobController.text.trim(),
      lastDegree: _selectedLastDegree!,
      lastCollegeName: _collegeController.text.trim(),
      district: _selectedDistrict!,
      categoryId: _selectedCategoryId!,
      courseId: _selectedCourseId!,
      referralCode: _referralCodeController.text.trim(),
    );

    if (!mounted || !success || !widget.authController.isLoggedIn) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            StudentDashboardScreen(authController: widget.authController),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingOptions) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: AppPageShell(
          maxWidth: 560,
          padding: const EdgeInsets.all(20),
          children: const [
            AppHeroBanner(
              title: 'Profile Setup',
              subtitle: 'Loading your academic setup options.',
              icon: Icons.account_circle_rounded,
              colors: [Color(0xFF2563EB), Color(0xFF0F766E)],
            ),
            SizedBox(height: 14),
            AppSurfaceCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadingError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: AppPageShell(
          maxWidth: 560,
          padding: const EdgeInsets.all(20),
          children: [
            const AppHeroBanner(
              title: 'Profile Setup',
              subtitle:
                  'We could not load your available categories and courses.',
              icon: Icons.account_circle_rounded,
              colors: [Color(0xFF2563EB), Color(0xFF0F766E)],
            ),
            const SizedBox(height: 14),
            AppSurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loadingError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _loadBootstrap,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('Complete Your Profile')),
        body: AppPageShell(
          maxWidth: 560,
          padding: const EdgeInsets.all(20),
          children: [
            const AppHeroBanner(
              title: 'Profile Setup',
              subtitle:
                  'One-time academic details to personalize your dashboard',
              icon: Icons.account_circle_rounded,
              colors: [Color(0xFF2563EB), Color(0xFF0F766E)],
            ),
            const SizedBox(height: 14),
            AppSurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal & Academic Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please complete this once to unlock your student dashboard modules.',
                      style: TextStyle(color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                      validator: (value) {
                        final raw = value?.trim() ?? '';
                        if (raw.isEmpty) {
                          return 'Phone number is required';
                        }
                        if (!_nepaliMobileRegex.hasMatch(raw)) {
                          return 'Enter a valid Nepali mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth',
                        prefixIcon: Icon(Icons.cake_rounded),
                        suffixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      onTap: () async {
                        final now = DateTime.now();
                        final initial =
                            DateTime.tryParse(_dobController.text) ??
                            DateTime(now.year - 18, now.month, now.day);
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime(1900, 1, 1),
                          lastDate: now,
                        );
                        if (picked != null) {
                          setState(() {
                            _dobController.text = picked
                                .toIso8601String()
                                .split('T')
                                .first;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Date of birth is required';
                        }
                        final parsed = DateTime.tryParse(value.trim());
                        if (parsed == null ||
                            !parsed.isBefore(DateTime.now())) {
                          return 'Enter a valid date of birth';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLastDegree,
                      items: _lastDegreeOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLastDegree = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Last Degree',
                        prefixIcon: Icon(Icons.workspace_premium_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Last degree is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _collegeController,
                      onChanged: _searchCollegeSuggestions,
                      decoration: const InputDecoration(
                        labelText: 'Last College Name',
                        prefixIcon: Icon(Icons.school_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Last college name is required';
                        }
                        return null;
                      },
                    ),
                    if (_loadingCollegeSuggestions) ...[
                      const SizedBox(height: 6),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (_collegeSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _collegeSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _collegeSuggestions[index];
                            return ListTile(
                              dense: true,
                              title: Text(suggestion),
                              onTap: () {
                                setState(() {
                                  _collegeController.text = suggestion;
                                  _collegeSuggestions = const [];
                                });
                                FocusScope.of(context).unfocus();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _referralCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Referral Code (Optional)',
                        prefixIcon: Icon(Icons.card_giftcard_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDistrict,
                      isExpanded: true,
                      selectedItemBuilder: (context) => _districtOptions
                          .map(
                            (district) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                district,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      items: _districtOptions
                          .map(
                            (district) => DropdownMenuItem<String>(
                              value: district,
                              child: Text(
                                district,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDistrict = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'District',
                        prefixIcon: Icon(Icons.location_city_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'District is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      isExpanded: true,
                      selectedItemBuilder: (context) => _categories
                          .map(
                            (category) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem<int>(
                              value: category.id,
                              child: Text(
                                category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _onCategoryChanged,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCourseId,
                      isExpanded: true,
                      selectedItemBuilder: (context) => _availableCourses
                          .map(
                            (course) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                course.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      items: _availableCourses
                          .map(
                            (course) => DropdownMenuItem<int>(
                              value: course.id,
                              child: Text(
                                course.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCourseId = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Course',
                        prefixIcon: Icon(Icons.menu_book_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (widget.authController.errorMessage != null)
                      Text(
                        widget.authController.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.authController.isLoading
                            ? null
                            : _submit,
                        child: widget.authController.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Complete Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelValueOption {
  const _LabelValueOption({required this.label, required this.value});

  final String label;
  final String value;
}
