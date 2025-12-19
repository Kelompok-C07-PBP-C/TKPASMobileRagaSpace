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

typedef AccountUserIdProvider = int? Function();
typedef AccountFetchFn = Future<Map<String, dynamic>> Function(Api api, int userId);
typedef AccountUpdateFn = Future<Map<String, dynamic>> Function(
  Api api, {
  required int userId,
  required String username,
  required String email,
  required String firstName,
  required String lastName,
  required String phoneNumber,
  File? avatarFile,
  Uint8List? avatarBytes,
  String? avatarFilename,
});
typedef AccountChangePasswordFn = Future<void> Function(
  Api api, {
  required int userId,
  required String currentPassword,
  required String newPassword,
  required String confirmPassword,
});
typedef AccountAvatarImageFactory = ImageProvider<Object> Function(
  File? file,
  String? url,
);

/// Test-only overrides used by widget tests.
AccountUserIdProvider? accountUserIdOverride;
AccountFetchFn? accountFetchOverride;
AccountUpdateFn? accountUpdateOverride;
AccountChangePasswordFn? accountChangePasswordOverride;
AccountAvatarImageFactory? accountAvatarImageFactoryOverride;

int? _getCurrentUserId() =>
    accountUserIdOverride != null ? accountUserIdOverride!() : Api.currentUserId;

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, this.picker});

  /// Optional override for image picker, used in tests.
  final ImagePicker? picker;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = true;
  bool _savingProfile = false;
  String? _error;
  String? _avatarUrl;
  File? _avatarFile;
  Uint8List? _avatarBytes;
  String? _avatarFilename;

  late final ImagePicker _picker;

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
    _loadAccount();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      setState(() {
        _error = 'Please log in again to edit your account.';
        _loading = false;
      });
      return;
    }
    try {
      final api = Api();
      final data = accountFetchOverride != null
          ? await accountFetchOverride!(api, userId)
          : await api.fetchAccount(userId);
      setState(() {
        _usernameCtrl.text = (data['username'] ?? '').toString();
        _emailCtrl.text = (data['email'] ?? '').toString();
        _firstNameCtrl.text = (data['first_name'] ?? '').toString();
        _lastNameCtrl.text = (data['last_name'] ?? '').toString();
        _phoneCtrl.text = (data['phone_number'] ?? '').toString();
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
    final bytes = await picked.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
      _avatarFilename = picked.name.isNotEmpty ? picked.name : picked.path.split('/').last;
      _avatarFile = kIsWeb ? null : File(picked.path);
    });
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
        title: Text('Account settings', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700)),
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
      child: Container(
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
            Center(child: _buildAvatar()),
            const SizedBox(height: 24),
            _buildTextField(_usernameCtrl, label: 'Username'),
            const SizedBox(height: 16),
            _buildTextField(_emailCtrl, label: 'Email', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildTextField(_firstNameCtrl, label: 'First name'),
            const SizedBox(height: 16),
            _buildTextField(_lastNameCtrl, label: 'Last name'),
            const SizedBox(height: 16),
            _buildTextField(
              _phoneCtrl,
              label: 'Phone number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
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
    if (_avatarBytes != null) {
      final provider = accountAvatarImageFactoryOverride != null
          ? accountAvatarImageFactoryOverride!(null, null)
          : MemoryImage(_avatarBytes!);
      avatarWidget = CircleAvatar(
        radius: 48,
        backgroundImage: provider as ImageProvider<Object>,
      );
    } else if (_avatarFile != null) {
      final provider = accountAvatarImageFactoryOverride != null
          ? accountAvatarImageFactoryOverride!(_avatarFile, null)
          : FileImage(_avatarFile!);
      avatarWidget = CircleAvatar(
        radius: 48,
        backgroundImage: provider,
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      final provider = accountAvatarImageFactoryOverride != null
          ? accountAvatarImageFactoryOverride!(null, _avatarUrl)
          : NetworkImage(_avatarUrl!);
      avatarWidget = CircleAvatar(
        radius: 48,
        backgroundImage: provider,
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
                  color: Theme.of(context).colorScheme.primary,
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

  // Test-only helpers to reach internal logic from widget tests.
  Future<void> debugSaveProfileForTests() => _saveProfile();
  void debugSetProfileFieldsForTests({String? username, String? phoneNumber}) {
    if (username != null) _usernameCtrl.text = username;
    if (phoneNumber != null) _phoneCtrl.text = phoneNumber;
  }

  void debugSetAvatarForTests({File? file, String? url}) {
    setState(() {
      _avatarFile = file;
      _avatarUrl = url;
    });
  }

  Widget debugBuildAvatarForTests() => _buildAvatar();
}
