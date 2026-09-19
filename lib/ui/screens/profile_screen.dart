import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models.dart';
import '../../data/profile_photo_service.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/logout_button.dart';
import '../widgets/profile_avatar.dart';

const _genders = ['Male', 'Female', 'Other'];

/// Business profile — name, owner age, gender. Phone number is shown
/// read-only since it's the account's login identity, not editable here.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _age = TextEditingController();
  String? _gender;
  AppUser? _user;
  bool _loading = true;
  bool _saving = false;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await Repos.instance.users.getUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _businessName.text = user?.businessName ?? '';
      _age.text = user?.ownerAge?.toString() ?? '';
      _gender = user?.ownerGender;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _businessName.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _user == null) return;
    setState(() => _saving = true);
    try {
      await Repos.instance.users.updateProfile(
        _user!.copyWith(
          businessName: _businessName.text.trim(),
          ownerAge: int.tryParse(_age.text.trim()),
          ownerGender: _gender,
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || _user == null) return;
    setState(() => _photoBusy = true);
    try {
      final oldPath = _user!.profilePicPath;
      final newPath = await ProfilePhotoService.save(picked);
      final updated = _user!.copyWith(profilePicPath: newPath);
      await Repos.instance.users.updateProfile(updated);
      if (oldPath != null && oldPath != newPath) {
        await ProfilePhotoService.delete(oldPath);
      }
      if (mounted) setState(() => _user = updated);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_user == null || _user!.profilePicPath == null) return;
    setState(() => _photoBusy = true);
    try {
      final oldPath = _user!.profilePicPath;
      final updated = _user!.copyWith(clearProfilePic: true);
      await Repos.instance.users.updateProfile(updated);
      await ProfilePhotoService.delete(oldPath);
      if (mounted) setState(() => _user = updated);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _showPhotoSheet() async {
    final hasPhoto = _user?.profilePicPath != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.card),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.negative),
                title: Text(
                  'Remove photo',
                  style: TextStyle(color: AppColors.negative),
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;
    switch (choice) {
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
        break;
      case 'camera':
        await _pickPhoto(ImageSource.camera);
        break;
      case 'remove':
        await _removePhoto();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _photoBusy ? null : _showPhotoSheet,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ProfileAvatar(
                              path: _user?.profilePicPath,
                              size: 92,
                            ),
                            if (_photoBusy)
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'PHONE NUMBER',
                      ),
                      child: Text(
                        _user?.username ?? '',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _businessName,
                      decoration: const InputDecoration(
                        labelText: 'BUSINESS NAME',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'OWNER AGE (OPTIONAL)',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 1 || n > 120) {
                          return 'Enter a valid age';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'GENDER (OPTIONAL)',
                      ),
                      items: [
                        for (final g in _genders)
                          DropdownMenuItem(value: g, child: Text(g)),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'SAVING...' : 'SAVE'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LogoutButton(),
                  ],
                ),
              ),
            ),
    );
  }
}
