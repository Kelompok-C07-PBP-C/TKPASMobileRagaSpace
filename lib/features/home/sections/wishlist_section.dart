part of 'package:marco/features/home/home_screen.dart';

const _wishlistStorageBaseKey = 'wishlist_venues';

@visibleForTesting
typedef WishlistFetchOverride = Future<List<Map<String, dynamic>>> Function({
  required int userId,
});

@visibleForTesting
typedef WishlistAddOverride = Future<Map<String, dynamic>> Function({
  required int userId,
  required int venueId,
});

@visibleForTesting
typedef WishlistRemoveOverride = Future<void> Function({
  required int userId,
  required int venueId,
});

@visibleForTesting
typedef WishlistHttpGetOverride = Future<http.Response> Function(Uri uri);

@visibleForTesting
WishlistFetchOverride? wishlistFetchOverride;

@visibleForTesting
WishlistAddOverride? wishlistAddOverride;

@visibleForTesting
WishlistRemoveOverride? wishlistRemoveOverride;

@visibleForTesting
WishlistHttpGetOverride? wishlistHttpGetOverride;

@visibleForTesting
int? wishlistUserIdOverride;

mixin _HomeWishlistSection on _HomeScreenCore {

  String _resolveWishlistStorageKey() {
    final userId = Api.currentUserId;
    if (userId != null) return '$_wishlistStorageBaseKey:$userId';
    return '$_wishlistStorageBaseKey:guest';
  }

  Future<void> _loadWishlist() async {
    final seed = await _restoreWishlistFromStorage();
    if (!mounted) return;
    unawaited(_syncWishlistFromServer(localSeed: seed));
  }

  Future<List<_VenueCardData>> _restoreWishlistFromStorage() async {
    _prefs ??= await SharedPreferences.getInstance();
    final storageKey = _resolveWishlistStorageKey();
    final stored = _prefs!.getStringList(storageKey) ?? [];
    final parsed = <_VenueCardData>[];
    var needsPersist = false;
    for (final item in stored) {
      try {
        parsed.add(_VenueCardData.fromMap(jsonDecode(item)));
      } catch (_) {
        needsPersist = true;
      }
    }
    var cleaned = parsed.where((item) => item.id != null).toList();
    needsPersist = needsPersist || cleaned.length != parsed.length;
    try {
      final existingIds = await _fetchAllVenueIds();
      if (existingIds != null && existingIds.isNotEmpty) {
        final filtered = cleaned
            .where((item) => item.id != null && existingIds.contains(item.id))
            .toList();
        if (filtered.length != cleaned.length) {
          cleaned = filtered;
          needsPersist = true;
        }
      }
    } catch (_) {
      // ignore network errors; fallback to currently known items
    }
    if (needsPersist) {
      final encoded = cleaned.map((e) => jsonEncode(e.toMap())).toList();
      await _prefs!.setStringList(storageKey, encoded);
    }
    if (mounted) {
      setState(() {
        _wishlist = cleaned;
        _wishlistKeys = cleaned.map((e) => e.storageKey).toSet();
      });
    }
    return cleaned;
  }

  @override
  Future<void> _loadProfileSummary() async {
    final userId = venueAccountUserIdOverride ?? Api.currentUserId;
    if (userId == null) return;
    try {
      final api = Api();
      final data = venueAccountFetchOverride != null
          ? await venueAccountFetchOverride!(api, userId)
          : await api.fetchAccount(userId);
      final avatar = (data['avatar_url'] ?? '').toString();
      final phone = (data['phone_number'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _avatarUrl = avatar;
        _accountPhoneNumber = phone;
      });
    } catch (_) {
      // ignore failure; keep placeholder avatar
    }
  }

  Future<Set<int>?> _fetchAllVenueIds() async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/venues/');
      final res = wishlistHttpGetOverride != null
          ? await wishlistHttpGetOverride!(uri)
          : await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final payload = jsonDecode(res.body) as List<dynamic>;
      final ids = <int>{};
      for (final raw in payload) {
        final map = raw as Map<String, dynamic>;
        final idValue = map['id'];
        final parsed = idValue is int ? idValue : int.tryParse('$idValue');
        if (parsed != null) ids.add(parsed);
      }
      return ids;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistWishlist() async {
    _prefs ??= await SharedPreferences.getInstance();
    final storageKey = _resolveWishlistStorageKey();
    final seen = <String>{};
    final encoded = <String>[];
    for (final item in _wishlist) {
      final key = item.storageKey;
      if (seen.add(key)) {
        encoded.add(jsonEncode(item.toMap()));
      }
    }
    await _prefs!.setStringList(storageKey, encoded);
  }

  @override
  Future<void> _syncWishlistFromServer({
    List<_VenueCardData>? localSeed,
    bool silent = true,
  }) async {
    final userId = wishlistUserIdOverride ?? Api.currentUserId;
    if (userId == null) return;
    try {
      final api = Api();
      final payloads = wishlistFetchOverride != null
          ? await wishlistFetchOverride!(userId: userId)
          : await api.fetchWishlist(userId: userId);
      final syncedItems = <_VenueCardData>[];
      final syncedKeys = <String>{};
      for (final entry in payloads) {
        try {
          final data = _VenueCardData.fromWishlistPayload(entry);
          final key = data.storageKey;
          if (key.isEmpty || syncedKeys.contains(key)) continue;
          syncedItems.add(data);
          syncedKeys.add(key);
        } catch (_) {
          continue;
        }
      }
      if (!mounted) return;
      setState(() {
        _wishlist = syncedItems;
        _wishlistKeys = syncedKeys;
      });
      await _persistWishlist();
    } catch (err) {
      if (!silent && mounted) {
        _showWishlistError(err);
      }
    }
  }

  @override
  Future<void> _toggleWishlist(_VenueCardData data) async {
    final key = data.storageKey;
    final adding = !_wishlistKeys.contains(key);
    final previousList = List<_VenueCardData>.from(_wishlist);
    final previousKeys = Set<String>.from(_wishlistKeys);
    setState(() {
      _wishlist.removeWhere((item) => item.storageKey == key);
      if (adding) {
        _wishlist.add(data);
        _wishlistKeys.add(key);
      } else {
        _wishlistKeys.remove(key);
      }
    });
    try {
      final userId = wishlistUserIdOverride ?? Api.currentUserId;
      if (userId != null && data.id != null) {
        if (adding) {
          final api = Api();
          final payload = wishlistAddOverride != null
              ? await wishlistAddOverride!(userId: userId, venueId: data.id!)
              : await api.addWishlistItem(
                  userId: userId,
                  venueId: data.id!,
                );
          final synced = _VenueCardData.fromWishlistPayload(payload);
          if (mounted) {
            setState(() {
              _wishlist.removeWhere((item) => item.storageKey == key);
              _wishlist.add(synced);
              _wishlistKeys.add(key);
            });
          }
        } else {
          final api = Api();
          if (wishlistRemoveOverride != null) {
            await wishlistRemoveOverride!(
              userId: userId,
              venueId: data.id!,
            );
          } else {
            await api.removeWishlistItem(
              userId: userId,
              venueId: data.id!,
            );
          }
        }
      }
      await _persistWishlist();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _wishlist = previousList;
        _wishlistKeys = previousKeys;
      });
      _showWishlistError(err);
    }
  }

  @override
  Future<bool> _toggleWishlistAndReturn(_VenueCardData data) async {
    await _toggleWishlist(data);
    return _wishlistKeys.contains(data.storageKey);
  }

  /// Helper used by the wishlist screen to refresh its contents while it is
  /// already visible. Returns the latest in-memory list so the screen can
  /// update without needing to know about the underlying storage.
  Future<List<_VenueCardData>> _syncWishlistForScreen() async {
    await _syncWishlistFromServer(localSeed: _wishlist, silent: true);
    return List<_VenueCardData>.from(_wishlist);
  }

  void _showWishlistError(Object error) {
    if (!mounted) return;
    final message = error is ApiError
        ? error.message
        : 'Gagal memperbarui wishlist. Coba lagi.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // -- Test helpers ---------------------------------------------------------

  @visibleForTesting
  Future<List<_VenueCardData>> debugRestoreWishlistFromStorageForTests() {
    return _restoreWishlistFromStorage();
  }

  @visibleForTesting
  Future<Set<int>?> debugFetchAllVenueIdsForTests() {
    return _fetchAllVenueIds();
  }

  @visibleForTesting
  Future<void> debugSyncWishlistFromServerForTests({
    List<_VenueCardData>? localSeed,
    bool silent = true,
  }) {
    return _syncWishlistFromServer(localSeed: localSeed, silent: silent);
  }

  @visibleForTesting
  List<_VenueCardData> debugWishlistItemsForTests() {
    return List<_VenueCardData>.from(_wishlist);
  }

  @visibleForTesting
  Set<String> debugWishlistKeysForTests() {
    return Set<String>.from(_wishlistKeys);
  }

  @visibleForTesting
  Future<bool> debugToggleWishlistAndReturnForTests(_VenueCardData data) {
    return _toggleWishlistAndReturn(data);
  }
}
