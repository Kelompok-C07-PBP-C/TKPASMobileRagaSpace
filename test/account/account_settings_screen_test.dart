import 'dart:io';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tk2ragaspace/features/account_settings/account_settings_screen.dart';
import 'package:tk2ragaspace/services/api.dart';

class _FakePicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    // Return a dummy file path so _pickAvatar follows the non-null branch
    // without hitting real platform channels.
    return XFile('dummy_avatar.png');
  }
}

class _SolidColorImageProvider
    extends ImageProvider<_SolidColorImageProvider> {
  const _SolidColorImageProvider();

  @override
  Future<_SolidColorImageProvider> obtainKey(
          ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      _SolidColorImageProvider key, ImageDecoderCallback decode) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), paint);
    final picture = recorder.endRecording();
    final imageFuture = picture.toImage(1, 1);
    return OneFrameImageStreamCompleter(
      imageFuture.then((image) => ImageInfo(image: image)),
    );
  }
}

void main() {
  setUp(() {
    accountAvatarImageFactoryOverride = (file, url) =>
        const _SolidColorImageProvider();
  });

  tearDown(() {
    accountUserIdOverride = null;
    accountFetchOverride = null;
    accountUpdateOverride = null;
    accountChangePasswordOverride = null;
    accountAvatarImageFactoryOverride = null;
  });

  testWidgets(
      'AccountSettingsScreen loads account and saves profile successfully',
      (tester) async {
    accountUserIdOverride = () => 42;
    accountFetchOverride = (api, userId) async => {
          'username': 'tk2ragaspace',
          'email': 'tk2ragaspace@example.com',
          'first_name': 'tk2ragaspace',
          'last_name': 'Polo',
          'phone_number': '08123',
          'avatar_url': '',
        };

    final updateCalls = <Map<String, dynamic>>[];
    accountUpdateOverride = (api,
        {required userId,
        required username,
        required email,
        required firstName,
        required lastName,
        required phoneNumber,
        File? avatarFile,
        Uint8List? avatarBytes,
        String? avatarFilename}) async {
      updateCalls.add({
        'userId': userId,
        'username': username,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'avatarFile': avatarFile?.path,
      });
      return {
        // Empty string avoids creating a real NetworkImage during tests.
        'avatar_url': '',
      };
    };

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsScreen(
          picker: _FakePicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Form fields are populated from fetchAccount.
    expect(find.text('tk2ragaspace'), findsOneWidget);
    expect(find.text('tk2ragaspace@example.com'), findsOneWidget);

    // Grab the state so we can invoke debug helpers directly (avoids off-screen taps).
    final dynamic state =
        tester.state(find.byType(AccountSettingsScreen));

    // Trigger avatar picker (FakePicker returns null but exercises _pickAvatar).
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump();

    // Exercise avatar branches in the state.
    state.debugSetAvatarForTests(file: File('dummy_avatar.png'), url: null);
    await tester.pump();
    state.debugSetAvatarForTests(file: null, url: 'https://example.com/avatar.png');
    await tester.pump();

    // Cover default FileImage/NetworkImage providers off-tree to avoid real IO.
    accountAvatarImageFactoryOverride = null;
    state.debugSetAvatarForTests(file: File('dummy_avatar.png'), url: null);
    state.debugBuildAvatarForTests();
    state.debugSetAvatarForTests(file: null, url: 'https://example.com/avatar.png');
    state.debugBuildAvatarForTests();
    accountAvatarImageFactoryOverride =
        (file, url) => const _SolidColorImageProvider();

    // Session expired during save: user id null branch.
    accountUserIdOverride = () => null;
    await state.debugSaveProfileForTests();
    await tester.pump();

    // Empty username branch.
    accountUserIdOverride = () => 42;
    state.debugSetProfileFieldsForTests(username: '');
    await state.debugSaveProfileForTests();
    await tester.pump();

    // Empty phone number branch.
    state.debugSetProfileFieldsForTests(username: 'tk2ragaspace', phoneNumber: '');
    await state.debugSaveProfileForTests();
    await tester.pump();

    // Valid data -> updateAccount success path.
    state.debugSetProfileFieldsForTests(username: 'tk2ragaspace', phoneNumber: '08123');
    await state.debugSaveProfileForTests();
    await tester.pumpAndSettle();

    expect(updateCalls, isNotEmpty);

    // Trigger change password success path.
    accountChangePasswordOverride = (api,
        {required userId,
        required currentPassword,
        required newPassword,
        required confirmPassword}) async {};

    state.debugSetPasswordFieldsForTests(
      currentPassword: 'old-pass',
      newPassword: 'new-pass',
      confirmPassword: 'new-pass',
    );

    await state.debugChangePasswordForTests();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'AccountSettingsScreen handles error, validation, and failure paths',
      (tester) async {
    // Scenario 1: _loadAccount error path and retry.
    accountUserIdOverride = () => 42;
    var loadCalls = 0;
    accountFetchOverride = (api, userId) async {
      loadCalls++;
      if (loadCalls == 1) {
        throw ApiError('network error');
      }
      return {
        'username': 'tk2ragaspace',
        'email': 'tk2ragaspace@example.com',
        'first_name': 'tk2ragaspace',
        'last_name': 'Polo',
        'phone_number': '08123',
        'avatar_url': '',
      };
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: AccountSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load account'), findsOneWidget);
    expect(find.textContaining('network error'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(loadCalls, 2);

    // Scenario 2: updateAccount throws and password change validations.
    accountUserIdOverride = () => 42;
    accountFetchOverride = (api, userId) async => {
          'username': 'marco',
          'email': 'marco@example.com',
          'first_name': 'Marco',
          'last_name': 'Polo',
          'phone_number': '08123',
          'avatar_url': '',
        };
    accountUpdateOverride = (api,
        {required userId,
        required username,
        required email,
        required firstName,
        required lastName,
        required String phoneNumber,
        File? avatarFile,
        Uint8List? avatarBytes,
        String? avatarFilename}) async {
      throw ApiError('update failed');
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: AccountSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final dynamic state =
        tester.state(find.byType(AccountSettingsScreen));

    // updateAccount throws -> catch branch.
    await state.debugSaveProfileForTests();
    await tester.pumpAndSettle();

    // Password change validation: missing fields.
    await state.debugChangePasswordForTests();
    await tester.pump();

    state.debugSetPasswordFieldsForTests(currentPassword: 'old');
    await state.debugChangePasswordForTests();
    await tester.pump();

    state.debugSetPasswordFieldsForTests(
      currentPassword: 'old',
      newPassword: 'new1',
      confirmPassword: 'new2',
    );
    await state.debugChangePasswordForTests();
    await tester.pump();

    // Now valid fields but no user id.
    state.debugSetPasswordFieldsForTests(confirmPassword: 'new1');
    accountUserIdOverride = () => null;
    await state.debugChangePasswordForTests();
    await tester.pump();

    // User id present but changePassword throws -> catch branch.
    accountUserIdOverride = () => 1;
    accountChangePasswordOverride = (api,
        {required userId,
        required currentPassword,
        required newPassword,
        required confirmPassword}) async {
      throw ApiError('change failed');
    };

    await state.debugChangePasswordForTests();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'AccountSettingsScreen shows login error when user id missing',
      (tester) async {
    accountUserIdOverride = () => null;

    await tester.pumpWidget(
      const MaterialApp(
        home: AccountSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Please log in again'),
      findsOneWidget,
    );
  });

  testWidgets(
      'AccountSettingsScreen calls Api methods when overrides are null',
      (tester) async {
    accountUserIdOverride = () => 99;
    accountFetchOverride = null;
    accountUpdateOverride = null;
    accountChangePasswordOverride = null;

    await tester.pumpWidget(
      const MaterialApp(
        home: AccountSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final dynamic state =
        tester.state(find.byType(AccountSettingsScreen));

    state.debugSetProfileFieldsForTests(
      username: 'api-user',
      phoneNumber: '08123',
    );

    await state.debugSaveProfileForTests();
    await tester.pumpAndSettle();

    state.debugSetPasswordFieldsForTests(
      currentPassword: 'old-pass',
      newPassword: 'new-pass',
      confirmPassword: 'new-pass',
    );
    await state.debugChangePasswordForTests();
    await tester.pumpAndSettle();
  });
}
