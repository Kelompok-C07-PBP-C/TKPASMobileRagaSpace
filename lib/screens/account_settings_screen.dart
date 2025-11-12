import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api.dart';
import '../widgets/gradient_button.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _loading = true;
  bool _savingProfile = false;
  bool _changingPassword = false;
  String? _error;
  String? _avatarUrl;
  File? _avatarFile;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    final userId = Api.currentUserId;
    if (userId == null) {
      setState(() {
        _error = 'Please log in again to edit your account.';
        _loading = false;
      });
      return;
    }
    try {
      final data = await Api().fetchAccount(userId);
      setState(() {
        _usernameCtrl.text = (data['username'] ?? '').toString();
        _emailCtrl.text = (data['email'] ?? '').toString();
        _firstNameCtrl.text = (data['first_name'] ?? '').toString();
        _lastNameCtrl.text = (data['last_name'] ?? '').toString();
        _avatarUrl = (data['avatar_url'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked == null) return;
    setState(() {
      _avatarFile = File(picked.path);
    });
  }

  Future<void> _saveProfile() async {
    final userId = Api.currentUserId;
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
    setState(() => _savingProfile = true);
    try {
      final data = await Api().updateAccount(
        userId: userId,
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        avatarFile: _avatarFile,
      );
      setState(() {
        _avatarUrl = (data['avatar_url'] ?? '').toString();
        _avatarFile = null;
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

  Future<void> _changePassword() async {
    final userId = Api.currentUserId;
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
    setState(() => _changingPassword = true);
    try {
      await Api().changePassword(
        userId: userId,
        currentPassword: _currentPassCtrl.text,
        newPassword: _newPassCtrl.text,
        confirmPassword: _confirmPassCtrl.text,
      );
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
    const gradient = LinearGradient(
      colors: [Color(0xFF0A1226), Color(0xFF0D1B32), Color(0xFF12325A), Color(0xFF1F4D7A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Account settings', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: gradient),
            ),
          ),
          Positioned.fill(
            child: Stack(
              children: [
                _decorOrb(alignment: Alignment(-0.6, -0.4), size: 220, color: const Color(0x4437E1A4)),
                _decorOrb(alignment: Alignment(0.8, -0.1), size: 180, color: const Color(0x3348B0F7)),
                _decorOrb(alignment: Alignment(0.2, 0.8), size: 260, color: const Color(0x332CD5FF)),
              ],
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : _error != null
                    ? _buildError()
                    : _buildForm(),
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
              'Unable to load account',
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
              onPressed: _loadAccount,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _buildAvatar()),
          const SizedBox(height: 16),
          _buildTextField(_usernameCtrl, label: 'Username'),
          const SizedBox(height: 16),
          _buildTextField(_emailCtrl, label: 'Email', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField(_firstNameCtrl, label: 'First name'),
          const SizedBox(height: 16),
          _buildTextField(_lastNameCtrl, label: 'Last name'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GradientButton(label: 'Save changes', onPressed: _savingProfile ? null : _saveProfile, loading: _savingProfile, colors: const [Color(0xFF1FA2FF), Color(0xFF2CD5FF)]),),
          const SizedBox(height: 32),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GradientButton(label: 'Update password', onPressed: _changingPassword ? null : _changePassword, loading: _changingPassword, colors: const [Color(0xFFFF7E79), Color(0xFFFF3D7E)]),),
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
    Widget avatarWidget;
    if (_avatarFile != null) {
      avatarWidget = CircleAvatar(
        radius: 48,
        backgroundImage: FileImage(_avatarFile!),
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(_avatarUrl!),
        backgroundColor: Colors.transparent,
      );
    } else {
      avatarWidget = placeholder;
    }
    return Column(
      children: [
        SizedBox(
          height: 108,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 8,
                child: avatarWidget,
              ),
              Positioned(
                bottom: 0,
                right: MediaQuery.of(context).size.width * 0.5 - 48 - 6,
                child: Material(
                  color: const Color(0xFF1FA2FF),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _pickAvatar,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.camera_alt_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap to update photo',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller,
      {required String label,
      TextInputType keyboardType = TextInputType.text,
      bool obscureText = false}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
      ),
    );
  }
  static Widget _decorOrb({required Alignment alignment, required double size, required Color color}) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0.04)]),
        ),
      ),
    );
  }
}









