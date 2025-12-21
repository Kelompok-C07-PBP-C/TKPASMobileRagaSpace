import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String? _error;

  String? _firstName;
  String? _lastName;
  String? _username;
  String? _email;
  String? _avatarUrl;

  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
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
    final username = (_username ?? '').trim();
    final displayName =
        nameParts.isNotEmpty ? nameParts.join(' ') : (username.isNotEmpty ? username : 'Unknown');
    final displayEmail = (_email ?? '').trim().isNotEmpty ? _email!.trim() : '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          _buildAvatar(),
          const SizedBox(height: 14),
          Text(
            displayName,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            displayEmail,
            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          _buildPasswordCard(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final placeholder = CircleAvatar(
      radius: 48,
      backgroundColor: Colors.white.withValues(alpha: 0.15),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 44),
    );

    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 52,
        backgroundImage: accountAvatarImageFactoryOverride != null
            ? accountAvatarImageFactoryOverride!(null, _avatarUrl)
            : NetworkImage(_avatarUrl!) as ImageProvider,
        backgroundColor: Colors.transparent,
      );
    }
    return placeholder;
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'Account settings',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                );
                if (mounted) _loadProfile();
              },
              colors: const [Color(0xFF45B1FF), Color(0xFF4BE2C7)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    required String label,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
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
