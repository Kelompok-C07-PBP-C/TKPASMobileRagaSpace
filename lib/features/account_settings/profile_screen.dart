import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tk2ragaspace/theme/aurora_palette.dart';
import 'package:tk2ragaspace/widgets/aurora_backdrop.dart';
import 'package:tk2ragaspace/widgets/twinkle_overlay.dart';

import '../../services/api.dart';
import '../../widgets/gradient_button.dart';
import 'account_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _changingPassword = false;
  bool _savingProfile = false;
  String? _error;
  bool _passwordExpanded = false;
  bool _settingsExpanded = false;
  bool _supportExpanded = false;

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _firstName;
  String? _lastName;
  String? _username;
  String? _avatarUrl;

  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  int? _getCurrentUserId() =>
      accountUserIdOverride != null ? accountUserIdOverride!() : Api.currentUserId;

  Future<void> _loadProfile() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      setState(() {
        _error = 'Please log in again to view your profile.';
        _loading = false;
      });
      return;
    }
    try {
      final api = Api();
      final data = accountFetchOverride != null
          ? await accountFetchOverride!(api, userId)
          : await api.fetchAccount(userId);
      if (!mounted) return;
      setState(() {
        _firstName = (data['first_name'] ?? '').toString();
        _lastName = (data['last_name'] ?? '').toString();
        final resolvedUsername = (data['username'] ?? '').toString();
        _username = resolvedUsername.isNotEmpty
            ? resolvedUsername
            : (Api.currentUsername ?? '');
        _avatarUrl = (data['avatar_url'] ?? '').toString();
        _usernameCtrl.text = _username ?? '';
        _emailCtrl.text = (data['email'] ?? '').toString();
        _firstNameCtrl.text = _firstName ?? '';
        _lastNameCtrl.text = _lastName ?? '';
        _phoneCtrl.text = (data['phone_number'] ?? '').toString();
        _email = (data['email'] ?? '').toString();
        _avatarUrl = (data['avatar_url'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load profile: $e';
        _loading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      return;
    }
    if (_currentPassCtrl.text.isEmpty ||
        _newPassCtrl.text.isEmpty ||
        _confirmPassCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill out all password fields.')),
      );
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password confirmation does not match.')),
      );
      return;
    }
    if (_newPassCtrl.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters.')),
      );
      return;
    }
    setState(() => _changingPassword = true);
    try {
      final api = Api();
      if (accountChangePasswordOverride != null) {
        await accountChangePasswordOverride!(
          api,
          userId: userId,
          currentPassword: _currentPassCtrl.text,
          newPassword: _newPassCtrl.text,
          confirmPassword: _confirmPassCtrl.text,
        );
      } else {
        await api.changePassword(
          userId: userId,
          currentPassword: _currentPassCtrl.text,
          newPassword: _newPassCtrl.text,
          confirmPassword: _confirmPassCtrl.text,
        );
      }
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: $e')),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
      _avatarFilename = picked.name.isNotEmpty ? picked.name : picked.path.split('/').last;
      _avatarFile = kIsWeb ? null : File(picked.path);
    });
    // Persist the new avatar immediately so it reflects across the app after leaving this page.
    await _saveProfile();
  }

  Future<void> _saveProfile() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      return;
    }
    if (_usernameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty.')),
      );
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number cannot be empty.')),
      );
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final api = Api();
      final data = accountUpdateOverride != null
          ? await accountUpdateOverride!(
              api,
              userId: userId,
              username: _usernameCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              firstName: _firstNameCtrl.text.trim(),
              lastName: _lastNameCtrl.text.trim(),
              phoneNumber: _phoneCtrl.text.trim(),
              avatarFile: kIsWeb ? null : _avatarFile,
              avatarBytes: _avatarBytes,
              avatarFilename: _avatarFilename,
            )
          : await api.updateAccount(
              userId: userId,
              username: _usernameCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              firstName: _firstNameCtrl.text.trim(),
              lastName: _lastNameCtrl.text.trim(),
              phoneNumber: _phoneCtrl.text.trim(),
              avatarFile: kIsWeb ? null : _avatarFile,
              avatarBytes: _avatarBytes,
              avatarFilename: _avatarFilename,
            );
      setState(() {
        _avatarUrl = (data['avatar_url'] ?? '').toString();
        _avatarFile = null;
        _avatarBytes = null;
        _avatarFilename = null;
        _username = _usernameCtrl.text.trim();
        _firstName = _firstNameCtrl.text.trim();
        _lastName = _lastNameCtrl.text.trim();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AuroraPalette.sky),
            ),
          ),
          const Positioned.fill(
            child: AuroraBackdrop(
              variant: AuroraBackdropVariant.dense,
              opacity: 0.65,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.25),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          const Positioned.fill(child: TwinkleOverlay(opacity: 0.16)),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : _error != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to load profile',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final nameParts = [
      if ((_firstName ?? '').trim().isNotEmpty) _firstName!.trim(),
      if ((_lastName ?? '').trim().isNotEmpty) _lastName!.trim(),
    ];
    final hasFullName = nameParts.isNotEmpty;
    final username = (_username ?? '').trim();
    final resolvedUsername =
        username.isNotEmpty ? username : (Api.currentUsername ?? 'Unknown user');
    final displayName = hasFullName ? nameParts.join(' ') : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          _buildAvatar(),
          const SizedBox(height: 12),
          if (displayName != null) ...[
            Text(
              displayName,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            _formatUsername(resolvedUsername),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: displayName == null ? 20 : 15,
              fontWeight: displayName == null ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _buildActionPanel(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final placeholder = CircleAvatar(
      radius: 52,
      backgroundColor: Colors.white.withValues(alpha: 0.15),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 48),
    );

    ImageProvider<Object>? provider;
    if (_avatarBytes != null && _avatarBytes!.isNotEmpty) {
      provider = accountAvatarImageFactoryOverride != null
          ? accountAvatarImageFactoryOverride!(null, null)
          : MemoryImage(_avatarBytes!);
    } else if (_avatarFile != null) {
      provider = accountAvatarImageFactoryOverride != null
          ? accountAvatarImageFactoryOverride!(_avatarFile, null)
          : FileImage(_avatarFile!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      provider = accountAvatarImageFactoryOverride != null
          ? accountAvatarImageFactoryOverride!(null, _avatarUrl)
          : NetworkImage(_avatarUrl!);
    }

    final avatar = provider != null
        ? CircleAvatar(radius: 52, backgroundImage: provider, backgroundColor: Colors.transparent)
        : placeholder;

    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          Positioned(
            bottom: 6,
            right: 6,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _pickAvatar,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF3D7BFF),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel() {
    return Column(
      children: [
        _buildAccordionTile(
          icon: Icons.lock_outline_rounded,
          label: 'Password',
          subtitle: 'Change your password',
          expanded: _passwordExpanded,
          onToggle: () => setState(() => _passwordExpanded = !_passwordExpanded),
          child: _buildPasswordCard(),
        ),
        const SizedBox(height: 12),
        _buildAccordionTile(
          icon: Icons.settings_rounded,
          label: 'Settings',
          subtitle: 'Account settings & profile',
          expanded: _settingsExpanded,
          onToggle: () => setState(() => _settingsExpanded = !_settingsExpanded),
          child: _buildSettingsCard(),
        ),
        const SizedBox(height: 12),
        _buildAccordionTile(
          icon: Icons.help_outline_rounded,
          label: 'Help & Support',
          subtitle: 'Contact & assistance',
          expanded: _supportExpanded,
          onToggle: () => setState(() => _supportExpanded = !_supportExpanded),
          child: _buildSupportCard(),
        ),
      ],
    );
  }

  Widget _buildAccordionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF353C52), Color(0xFF1E2437)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(icon, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.expand_more_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  crossFadeState:
                      expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xEE0E1728),
            Color(0xEE15263F),
            Color(0xEE0F3846),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update your account details and profile information.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 14),
          _buildTextField(_usernameCtrl, label: 'Username'),
          const SizedBox(height: 12),
          _buildTextField(_emailCtrl, label: 'Email', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _buildTextField(_firstNameCtrl, label: 'First name'),
          const SizedBox(height: 12),
          _buildTextField(_lastNameCtrl, label: 'Last name'),
          const SizedBox(height: 12),
          _buildTextField(_phoneCtrl, label: 'Phone number', keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'Save changes',
              onPressed: _savingProfile ? null : _saveProfile,
              loading: _savingProfile,
              colors: const [Color(0xFF45B1FF), Color(0xFF4BE2C7)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xEE0E1728),
            Color(0xEE15263F),
            Color(0xEE0F3846),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Help & Support',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hubungi kami bila butuh bantuan atau informasi lebih lanjut.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _SupportRow(
            heading: 'Contact',
            lines: const [
              '021 - 1234 5678',
              '@ragaspace',
              'ragaspace',
              'ragaspace@gmail.com',
            ],
          ),
          const SizedBox(height: 14),
          _SupportRow(
            heading: 'Company',
            lines: const [
              'About RagaSpace',
              'Careers',
              'Log and Media',
            ],
          ),
          const SizedBox(height: 14),
          _SupportRow(
            heading: 'Support',
            lines: const [
              'Support Docs',
              'Contact',
              'Partnership',
            ],
          ),
          const SizedBox(height: 14),
          _SupportRow(
            heading: 'Address',
            lines: const [
              'Jl. Wahid Hasyim No. 100',
              'Jakarta Pusat',
              'DKI Jakarta, Indonesia',
              '10340',
            ],
          ),
        ],
      ),
    );
  }

  String _formatUsername(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '@username';
    return trimmed.startsWith('@') ? trimmed : '@$trimmed';
  }

  Widget _buildPasswordCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          colors: [
            Color(0xCC0E1728),
            Color(0xCC15263F),
            Color(0xCC0F3846),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 35,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change password',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildTextField(
            _currentPassCtrl,
            label: 'Current password',
            obscureText: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _newPassCtrl,
            label: 'New password',
            obscureText: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _confirmPassCtrl,
            label: 'Confirm new password',
            obscureText: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'Update password',
              onPressed: _changingPassword ? null : _changePassword,
              loading: _changingPassword,
              colors: const [Color(0xFFFF7E79), Color(0xFFFF3D7E)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.09),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({required this.heading, required this.lines});

  final String heading;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            heading.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}