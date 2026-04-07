import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';
import '../../referral/pages/referral_dashboard_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static final RegExp _nepaliMobileRegex = RegExp(r'^9[78]\d{8}$');

  static const List<_LabelValue> _degreeOptions = [
    _LabelValue('SEE / 10', 'see'),
    _LabelValue('+2', '+2'),
    _LabelValue('Diploma', 'diploma'),
    _LabelValue('Bachelor', 'bachelor'),
    _LabelValue('Master', 'master'),
    _LabelValue('PhD', 'phd'),
  ];

  static const List<String> _districts = [
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

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#\$&*~_\-\^%\(\)\[\]\{\}\\|:;"<>,.?/]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  final _nameFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _deleteFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _collegeController = TextEditingController();

  String? _selectedDegree;
  String? _selectedDistrict;
  bool _loadingCollegeSuggestions = false;
  Timer? _collegeSearchDebounce;
  List<String> _collegeSuggestions = const [];

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deletePasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _showDeletePassword = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.authController.user?.name ?? '';
    _phoneController.text = widget.authController.user?.phone ?? '';
    _dobController.text = widget.authController.user?.dateOfBirth == null
        ? ''
        : widget.authController.user!.dateOfBirth!
              .toIso8601String()
              .split('T')
              .first;
    _collegeController.text = widget.authController.user?.lastCollegeName ?? '';
    _selectedDegree = widget.authController.user?.lastDegree;
    final district = widget.authController.user?.district;
    _selectedDistrict = _districts.contains(district) ? district : null;
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latestName = widget.authController.user?.name ?? '';
    final latestPhone = widget.authController.user?.phone ?? '';
    final latestDob = widget.authController.user?.dateOfBirth == null
        ? ''
        : widget.authController.user!.dateOfBirth!
              .toIso8601String()
              .split('T')
              .first;
    if (_nameController.text != latestName &&
        !_nameController.selection.isValid) {
      _nameController.text = latestName;
    }
    if (_phoneController.text != latestPhone &&
        !_phoneController.selection.isValid) {
      _phoneController.text = latestPhone;
    }
    if (_dobController.text != latestDob && !_dobController.selection.isValid) {
      _dobController.text = latestDob;
    }
    final latestCollege = widget.authController.user?.lastCollegeName ?? '';
    if (_collegeController.text != latestCollege &&
        !_collegeController.selection.isValid) {
      _collegeController.text = latestCollege;
    }
    _selectedDegree = widget.authController.user?.lastDegree;
    final latestDistrict = widget.authController.user?.district;
    _selectedDistrict = _districts.contains(latestDistrict)
        ? latestDistrict
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _collegeSearchDebounce?.cancel();
    _collegeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deletePasswordController.dispose();
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

  Future<void> _saveName() async {
    if (!_nameFormKey.currentState!.validate()) {
      return;
    }

    final ok = await widget.authController.updateProfileName(
      _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      dateOfBirth: _dobController.text.trim().isEmpty
          ? null
          : _dobController.text.trim(),
      lastDegree: _selectedDegree,
      lastCollegeName: _collegeController.text.trim().isEmpty
          ? null
          : _collegeController.text.trim(),
      district: _selectedDistrict,
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Profile updated successfully.'
              : (widget.authController.errorMessage ??
                    'Failed to update profile.'),
        ),
        backgroundColor: ok ? null : Colors.red,
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    final ok = await widget.authController.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      passwordConfirmation: _confirmPasswordController.text,
    );
    if (!mounted) {
      return;
    }

    if (ok) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Password changed successfully.'
              : (widget.authController.errorMessage ??
                    'Failed to change password.'),
        ),
        backgroundColor: ok ? null : Colors.red,
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (!_deleteFormKey.currentState!.validate()) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final ok = await widget.authController.deleteAccount(
      _deletePasswordController.text,
    );

    if (!mounted || ok) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.authController.errorMessage ?? 'Failed to delete account.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final user = widget.authController.user;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final loading = widget.authController.isLoading;
        if (_nameController.text.isEmpty) {
          _nameController.text = user.name;
        }

        return AppPageShell(
          maxWidth: 760,
          children: [
            const AppHeroBanner(
              title: 'Profile & Security',
              subtitle: 'Manage your account details, password, and safety.',
              icon: Icons.manage_accounts_rounded,
              colors: [Color(0xFF1D4ED8), Color(0xFF0891B2)],
            ),
            const SizedBox(height: 14),
            _Panel(
              child: Form(
                key: _nameFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      'Update Name',
                      'Update your display name.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: user.email,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF3F4F6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: user.username ?? 'N/A',
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF3F4F6),
                        hintText: 'System-generated unique identifier',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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
                      initialValue: _selectedDegree,
                      items: _degreeOptions
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.value,
                              child: Text(d.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDegree = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Last Degree',
                        border: OutlineInputBorder(),
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
                        labelText: 'Last College / School Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Last college/school is required';
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
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDistrict,
                      items: _districts
                          .map(
                            (district) => DropdownMenuItem(
                              value: district,
                              child: Text(district),
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
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'District is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: loading ? null : _saveName,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(loading ? 'Saving...' : 'Save Profile'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Panel(
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      'Change Password',
                      'Password must be at least 8 characters, include 1 uppercase, 1 number, and 1 special character.',
                    ),
                    const SizedBox(height: 16),
                    _PasswordField(
                      controller: _currentPasswordController,
                      label: 'Current Password',
                      visible: _showCurrentPassword,
                      onToggle: () => setState(
                        () => _showCurrentPassword = !_showCurrentPassword,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PasswordField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      visible: _showNewPassword,
                      onToggle: () =>
                          setState(() => _showNewPassword = !_showNewPassword),
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: 12),
                    _PasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      visible: _showConfirmPassword,
                      onToggle: () => setState(
                        () => _showConfirmPassword = !_showConfirmPassword,
                      ),
                      validator: (value) {
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: loading ? null : _changePassword,
                      icon: const Icon(Icons.key_rounded),
                      label: Text(loading ? 'Saving...' : 'Change Password'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    'Referral Program',
                    'Invite friends, track referrals, and earn coins together.',
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: widget.authController.accessToken == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReferralDashboardPage(
                                  token: widget.authController.accessToken!,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.card_giftcard_rounded),
                    label: const Text('Open Referral Dashboard'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DangerPanel(
              child: Form(
                key: _deleteFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      'Delete Account',
                      'Your account will be deleted. You can register again later with the same email if allowed by the backend.',
                    ),
                    const SizedBox(height: 16),
                    _PasswordField(
                      controller: _deletePasswordController,
                      label: 'Current Password',
                      visible: _showDeletePassword,
                      onToggle: () => setState(
                        () => _showDeletePassword = !_showDeletePassword,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                      onPressed: loading ? null : _deleteAccount,
                      icon: const Icon(Icons.delete_rounded),
                      label: Text(loading ? 'Deleting...' : 'Delete Account'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(padding: const EdgeInsets.all(18), child: child);
  }
}

class _DangerPanel extends StatelessWidget {
  const _DangerPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
          color: const Color(0xFFFFFBFB),
        ),
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggle,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return '$label is required';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          ),
        ),
      ),
    );
  }
}

class _LabelValue {
  const _LabelValue(this.label, this.value);

  final String label;
  final String value;
}
