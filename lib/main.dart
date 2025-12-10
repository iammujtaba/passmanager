import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PasswordManagerApp());
}

class PasswordManagerApp extends StatelessWidget {
  const PasswordManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A84FF)),
      useMaterial3: true,
      textTheme: GoogleFonts.ibmPlexSansTextTheme(),
    );

    return MaterialApp(
      title: 'Password Manager',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: StartupGate(secureTokenStore: SecureTokenStore()),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.secureTokenStore});

  final SecureTokenStore secureTokenStore;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<_StartupSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<_StartupSnapshot> _loadSnapshot() async {
    final hasToken = await widget.secureTokenStore.hasToken();
    final hasPin = await widget.secureTokenStore.hasPin();
    return _StartupSnapshot(hasToken: hasToken, hasPin: hasPin);
  }

  void _refresh() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  void _openHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(secureTokenStore: widget.secureTokenStore),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!;
        if (!data.hasToken) {
          return TokenSetupScreen(
            secureTokenStore: widget.secureTokenStore,
            onSetupComplete: _refresh,
          );
        }
        return AppLockScreen(
          secureTokenStore: widget.secureTokenStore,
          hasPin: data.hasPin,
          onUnlocked: _openHome,
        );
      },
    );
  }
}

class _StartupSnapshot {
  const _StartupSnapshot({required this.hasToken, required this.hasPin});

  final bool hasToken;
  final bool hasPin;
}

class TokenSetupScreen extends StatefulWidget {
  const TokenSetupScreen({super.key, required this.secureTokenStore, required this.onSetupComplete});

  final SecureTokenStore secureTokenStore;
  final VoidCallback onSetupComplete;

  @override
  State<TokenSetupScreen> createState() => _TokenSetupScreenState();
}

class _TokenSetupScreenState extends State<TokenSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _confirmTokenController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _confirmTokenController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final token = _tokenController.text.trim();
    final pin = _pinController.text.trim();
    await widget.secureTokenStore.saveToken(token);
    if (pin.isNotEmpty) {
      await widget.secureTokenStore.savePin(pin);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Master token saved successfully.')),
    );
    widget.onSetupComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up token')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter a strong master token for encryption. Optionally add a PIN for quick unlocks.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _tokenController,
                  decoration: const InputDecoration(labelText: 'Master token'),
                  obscureText: true,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Token is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmTokenController,
                  decoration: const InputDecoration(labelText: 'Confirm token'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Confirm the token';
                    }
                    if (value.trim() != _tokenController.text.trim()) {
                      return 'Tokens do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _pinController,
                  decoration: const InputDecoration(labelText: 'PIN (optional)'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                ),
                TextFormField(
                  controller: _confirmPinController,
                  decoration: const InputDecoration(labelText: 'Confirm PIN'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  validator: (value) {
                    final pin = _pinController.text.trim();
                    if (pin.isEmpty) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Confirm the PIN';
                    }
                    if (value.trim() != pin) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save and continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    super.key,
    required this.secureTokenStore,
    required this.hasPin,
    required this.onUnlocked,
  });

  final SecureTokenStore secureTokenStore;
  final bool hasPin;
  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _checkingBiometrics = false;
  bool _biometricsAvailable = false;
  bool _verifyingPin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareBiometrics();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _prepareBiometrics() async {
    if (kIsWeb) return;
    setState(() => _checkingBiometrics = true);
    bool available = false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      available = supported && canCheck;
    } on PlatformException {
      available = false;
    }
    if (!mounted) return;
    setState(() {
      _biometricsAvailable = available;
      _checkingBiometrics = false;
    });
  }

  Future<void> _authenticateBiometric() async {
    if (!_biometricsAvailable) return;
    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'Unlock to view passwords',
      );
      if (result && mounted) {
        widget.onUnlocked();
      }
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric authentication failed.')),
      );
    }
  }

  Future<void> _unlockWithPin() async {
    if (!widget.hasPin) {
      widget.onUnlocked();
      return;
    }

    setState(() {
      _verifyingPin = true;
      _error = null;
    });

    final matches = await widget.secureTokenStore.verifyPin(_pinController.text);
    if (!mounted) return;

    if (matches) {
      widget.onUnlocked();
    } else {
      setState(() {
        _verifyingPin = false;
        _error = 'Invalid PIN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.hasPin ? 'Enter PIN to unlock' : 'Unlock Password Manager';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 72, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (widget.hasPin)
                    TextField(
                      controller: _pinController,
                      decoration: InputDecoration(labelText: 'PIN', errorText: _error),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 8,
                    )
                  else
                    Text(
                      'No PIN configured. Use biometrics if available or continue below.',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _verifyingPin ? null : _unlockWithPin,
                      child: _verifyingPin
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(widget.hasPin ? 'Unlock' : 'Continue'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_biometricsAvailable)
                    OutlinedButton.icon(
                      onPressed: _authenticateBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use biometrics'),
                    )
                  else if (!_checkingBiometrics && !kIsWeb)
                    OutlinedButton.icon(
                      onPressed: _prepareBiometrics,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check biometrics'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.secureTokenStore});

  final SecureTokenStore secureTokenStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PasswordRepository _repository = PasswordRepository();
  late Future<List<PasswordEntry>> _entriesFuture;
  EncryptionService? _encryptionService;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedCategories = <String>{};
  final Set<String> _selectedTags = <String>{};
  String _twoFaFilter = 'all';

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        _selectedCategories.isNotEmpty ||
        _selectedTags.isNotEmpty ||
        _twoFaFilter != 'all';
  }

  String _extractJsonBlock(String raw) {
    final trimmed = raw.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    _entriesFuture = _repository.fetchEntries();
    _initEncryption();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initEncryption() async {
    final token = await widget.secureTokenStore.readToken();
    if (token == null) return;
    final service = await EncryptionService.fromToken(token);
    if (!mounted) return;
    setState(() {
      _encryptionService = service;
    });
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedCategories.clear();
      _selectedTags.clear();
      _twoFaFilter = 'all';
      _searchController.clear();
      _searchQuery = '';
    });
  }

  List<PasswordEntry> _filteredEntries(List<PasswordEntry> entries) {
    return entries.where((entry) {
      final normalizedQuery = _searchQuery.toLowerCase().trim();
      if (normalizedQuery.isNotEmpty) {
        final haystack = <String?>[
          entry.title,
          entry.username,
          entry.email,
          entry.website,
          entry.alias,
          entry.category,
          entry.description,
        ];
        final matchesQuery = haystack.any(
          (value) => value != null && value.toLowerCase().contains(normalizedQuery),
        );
        if (!matchesQuery) {
          final tagMatches = entry.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
          if (!tagMatches) return false;
        }
      }

      if (_selectedCategories.isNotEmpty) {
        final categoryLabel = (entry.category == null || entry.category!.trim().isEmpty)
            ? 'Uncategorized'
            : entry.category!;
        if (!_selectedCategories.contains(categoryLabel)) {
          return false;
        }
      }

      if (_selectedTags.isNotEmpty) {
        final lowercaseTags = entry.tags.map((tag) => tag.toLowerCase()).toSet();
        final hasMatch = _selectedTags.any((tag) => lowercaseTags.contains(tag.toLowerCase()));
        if (!hasMatch) return false;
      }

      if (_twoFaFilter == 'enabled' && !entry.isTwoFaEnabled) {
        return false;
      }
      if (_twoFaFilter == 'disabled' && entry.isTwoFaEnabled) {
        return false;
      }

      return true;
    }).toList();
  }

  Widget _buildFilters(List<PasswordEntry> entries) {
    final theme = Theme.of(context);
    final categoryCounts = <String, int>{};
    final tagCounts = <String, int>{};

    for (final entry in entries) {
      final categoryLabel = (entry.category == null || entry.category!.trim().isEmpty)
          ? 'Uncategorized'
          : entry.category!.trim();
      categoryCounts.update(categoryLabel, (value) => value + 1, ifAbsent: () => 1);
      for (final tag in entry.tags) {
        if (tag.trim().isEmpty) continue;
        tagCounts.update(tag.trim(), (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final sortedCategories = categoryCounts.keys.toList()..sort();
    final sortedTags = tagCounts.keys.toList()
      ..sort((a, b) => tagCounts[b]!.compareTo(tagCounts[a]!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search by title, email, website... ',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SummaryRow(entries: entries),
        const SizedBox(height: 24),
        Text('Categories', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (sortedCategories.isEmpty)
          Text('No categories yet', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedCategories
                .map(
                  (category) => FilterChip(
                    label: Text('$category (${categoryCounts[category]})'),
                    selected: _selectedCategories.contains(category),
                    onSelected: (_) => _toggleCategory(category),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 24),
        Text('Tags', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (sortedTags.isEmpty)
          Text('Add tags to unlock filtering', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedTags.take(12).map((tag) {
              final display = '$tag (${tagCounts[tag]})';
              return FilterChip(
                label: Text(display),
                selected: _selectedTags.contains(tag),
                onSelected: (_) => _toggleTag(tag),
              );
            }).toList(),
          ),
        const SizedBox(height: 24),
        Text('Two-factor authentication', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(value: 'all', label: Text('All')),
            ButtonSegment<String>(value: 'enabled', label: Text('Enabled'), icon: Icon(Icons.verified_user)),
            ButtonSegment<String>(value: 'disabled', label: Text('Disabled'), icon: Icon(Icons.security_outlined)),
          ],
          selected: <String>{_twoFaFilter},
          onSelectionChanged: (selection) {
            setState(() {
              _twoFaFilter = selection.first;
            });
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset filters'),
          ),
        ),
      ],
    );
  }

  Future<void> _addOrEditEntry({PasswordEntry? entry}) async {
    if (_encryptionService == null) return;
    final updatedEntry = await showModalBottomSheet<PasswordEntry>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return PasswordEntrySheet(
          encryptionService: _encryptionService!,
          entry: entry,
        );
      },
    );
    if (updatedEntry != null) {
      final entries = await _repository.fetchEntries();
      final index = entries.indexWhere((e) => e.id == updatedEntry.id);
      if (index >= 0) {
        entries[index] = updatedEntry;
      } else {
        entries.add(updatedEntry);
      }
      await _repository.saveEntries(entries);
      if (!mounted) return;
      setState(() {
        _entriesFuture = Future.value(entries);
      });
    }
  }

  Future<void> _deleteEntry(String id) async {
    final entries = await _repository.fetchEntries();
    entries.removeWhere((element) => element.id == id);
    await _repository.saveEntries(entries);
    if (!mounted) return;
    setState(() {
      _entriesFuture = Future.value(entries);
    });
  }

  Future<void> _shareEntry(PasswordEntry entry) async {
    final payload = jsonEncode({
      'id': entry.id,
      'username': entry.username,
      'email': entry.email,
      'cipher': entry.encryptedPassword,
      'iv': entry.iv,
      'title': entry.title,
      'website': entry.website,
      'alias': entry.alias,
      'category': entry.category,
      'hint': entry.hint,
      'description': entry.description,
      'tags': entry.tags,
      'is_2fa_enabled': entry.isTwoFaEnabled,
      'two_fa_type': entry.twoFaType,
      'two_fa_backup_codes': entry.twoFaBackupCodes,
      'two_fa_backup_iv': entry.twoFaBackupIv,
      'password_last_changed_at': entry.passwordLastChangedAt,
      'created_at': entry.createdAt,
      'updated_at': entry.updatedAt,
    });
    final shareName = entry.username.isNotEmpty
        ? entry.username
        : (entry.email.isNotEmpty ? entry.email : 'account');
    await Share.share(payload, subject: 'Encrypted password for $shareName');
  }

  Future<void> _importSharedPayload() async {
    if (_encryptionService == null) return;
    final controller = TextEditingController();
    final payloadText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste shared JSON'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '{"username":"user","cipher":"..."}',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Import')),
        ],
      ),
    );
    if (payloadText == null || payloadText.isEmpty) return;
    try {
      final normalized = _extractJsonBlock(payloadText);
      final decoded = jsonDecode(normalized) as Map<String, dynamic>;
      final nowIso = DateTime.now().toIso8601String();
      final rawTags = decoded['tags'];
      List<String>? tags;
      if (rawTags is List) {
        tags = rawTags.map((e) => e.toString()).toList();
      } else if (rawTags is String) {
        tags = rawTags.split(',').map((e) => e.trim()).where((element) => element.isNotEmpty).toList();
      }
      final entry = PasswordEntry(
        id: decoded['id'] as String? ?? const Uuid().v4(),
        username: decoded['username'] as String? ?? '',
        email: decoded['email'] as String? ?? '',
        encryptedPassword: decoded['cipher'] as String,
        iv: decoded['iv'] as String,
        title: decoded['title'] as String?,
        website: decoded['website'] as String?,
        alias: decoded['alias'] as String?,
        category: decoded['category'] as String?,
        hint: decoded['hint'] as String?,
        description: decoded['description'] as String?,
        tags: tags,
        isTwoFaEnabled: decoded['is_2fa_enabled'] as bool? ?? false,
        twoFaType: decoded['two_fa_type'] as String?,
        twoFaBackupCodes: decoded['two_fa_backup_codes'] as String?,
        twoFaBackupIv: decoded['two_fa_backup_iv'] as String?,
        passwordLastChangedAt: decoded['password_last_changed_at'] as String?,
        createdAt: decoded['created_at'] as String? ?? nowIso,
        updatedAt: decoded['updated_at'] as String? ?? nowIso,
      );
      final decrypted = _encryptionService!.decrypt(
        EncryptedPayload(cipherText: entry.encryptedPassword, iv: entry.iv),
      );
      final entries = await _repository.fetchEntries();
      entries.add(entry);
      await _repository.saveEntries(entries);
      if (!mounted) return;
      setState(() {
        _entriesFuture = Future.value(entries);
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Decryption successful'),
          content: SelectableText('Password: $decrypted'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } catch (error, stack) {
      debugPrint('Import failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to import data: ${error.runtimeType}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Manager'),
        actions: [
          IconButton(
            tooltip: 'Import shared data',
            onPressed: _importSharedPayload,
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
          IconButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Lock the app?'),
                  content: const Text('This only locks the app.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                final hasPin = await widget.secureTokenStore.hasPin();
                if (!mounted) return;
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => AppLockScreen(
                      secureTokenStore: widget.secureTokenStore,
                      hasPin: hasPin,
                      onUnlocked: () {
                        navigator.pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => HomeScreen(secureTokenStore: widget.secureTokenStore),
                          ),
                        );
                      },
                    ),
                  ),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.lock_reset),
          ),
        ],
      ),
      body: FutureBuilder<List<PasswordEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          final filteredEntries = _filteredEntries(entries);
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1024;
              if (isWide) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 360,
                        child: SingleChildScrollView(child: _buildFilters(entries)),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: filteredEntries.isEmpty
                            ? Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 520),
                                  child: _EmptyStateCard(
                                    hasEntries: entries.isNotEmpty,
                                    filtersActive: _hasActiveFilters,
                                    onCreate: _encryptionService == null ? null : () => _addOrEditEntry(),
                                    onReset: _hasActiveFilters ? _resetFilters : null,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 160),
                                itemBuilder: (context, index) {
                                  final entry = filteredEntries[index];
                                  return PasswordTile(
                                    entry: entry,
                                    encryptionService: _encryptionService,
                                    onDelete: () => _deleteEntry(entry.id),
                                    onEdit: () => _addOrEditEntry(entry: entry),
                                    onShare: () => _shareEntry(entry),
                                  );
                                },
                                separatorBuilder: (_, __) => const SizedBox(height: 16),
                                itemCount: filteredEntries.length,
                              ),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFilters(entries),
                  const SizedBox(height: 24),
                  if (filteredEntries.isEmpty)
                    _EmptyStateCard(
                      hasEntries: entries.isNotEmpty,
                      filtersActive: _hasActiveFilters,
                      onCreate: _encryptionService == null ? null : () => _addOrEditEntry(),
                      onReset: _hasActiveFilters ? _resetFilters : null,
                    )
                  else ...[
                    for (final entry in filteredEntries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PasswordTile(
                          entry: entry,
                          encryptionService: _encryptionService,
                          onDelete: () => _deleteEntry(entry.id),
                          onEdit: () => _addOrEditEntry(entry: entry),
                          onShare: () => _shareEntry(entry),
                        ),
                      ),
                  ],
                  const SizedBox(height: 96),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _encryptionService == null ? null : () => _addOrEditEntry(),
        icon: const Icon(Icons.add),
        label: const Text('New password'),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.hasEntries,
    required this.filtersActive,
    this.onReset,
    this.onCreate,
  });

  final bool hasEntries;
  final bool filtersActive;
  final VoidCallback? onReset;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = hasEntries
        ? 'No entries match these filters'
        : 'Your vault is empty';
    final subtitle = hasEntries
        ? 'Try widening your filters or resetting search to see more passwords.'
        : 'Add your first password to start storing encrypted credentials here.';
    final icon = hasEntries ? Icons.filter_alt_off : Icons.rocket_launch_outlined;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(icon, size: 32, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                if (filtersActive && onReset != null)
                  OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset filters'),
                  ),
                if (onCreate != null)
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Add password'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.entries});

  final List<PasswordEntry> entries;

  @override
  Widget build(BuildContext context) {
    final total = entries.length;
    final twoFaEnabled = entries.where((e) => e.isTwoFaEnabled).length;
    final categories = entries
        .map(
          (e) => (e.category == null || e.category!.trim().isEmpty) ? 'Uncategorized' : e.category!.trim(),
        )
        .toSet()
      ..removeWhere((element) => element.isEmpty);
    final tags = entries.expand((e) => e.tags).map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toSet();

    final cards = [
      _SummaryStatCard(title: 'Total entries', value: '$total', icon: Icons.key_rounded),
      _SummaryStatCard(title: '2FA protected', value: '$twoFaEnabled', icon: Icons.verified_user),
      _SummaryStatCard(title: 'Categories', value: '${categories.isEmpty ? 0 : categories.length}', icon: Icons.folder),
      _SummaryStatCard(title: 'Tags', value: '${tags.length}', icon: Icons.sell),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (card) => SizedBox(
              width: 180,
              child: card,
            ),
          )
          .toList(),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class PasswordTile extends StatefulWidget {
  const PasswordTile({
    super.key,
    required this.entry,
    required this.encryptionService,
    required this.onDelete,
    required this.onEdit,
    required this.onShare,
  });

  final PasswordEntry entry;
  final EncryptionService? encryptionService;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  @override
  State<PasswordTile> createState() => _PasswordTileState();
}

class _PasswordTileState extends State<PasswordTile> {
  bool _revealed = false;
  String? _plainPassword;
  String? _plainTwoFaCodes;

  String? _formatTimestamp(String? iso) {
    if (iso == null) return null;
    try {
      final parsed = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(parsed);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _toggleReveal() async {
    if (!_revealed) {
      try {
        final service = widget.encryptionService;
        if (service == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unlock the app before revealing.')),
          );
          return;
        }
        final decrypted = service.decrypt(
          EncryptedPayload(cipherText: widget.entry.encryptedPassword, iv: widget.entry.iv),
        );
        String? backup;
        if (widget.entry.twoFaBackupCodes != null && widget.entry.twoFaBackupIv != null) {
          backup = service.decrypt(
            EncryptedPayload(
              cipherText: widget.entry.twoFaBackupCodes!,
              iv: widget.entry.twoFaBackupIv!,
            ),
          );
        }
        setState(() {
          _plainPassword = decrypted;
          _plainTwoFaCodes = backup;
          _revealed = true;
        });
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Decryption failed. Check your token.')),
        );
      }
    } else {
      setState(() {
        _revealed = false;
        _plainPassword = null;
        _plainTwoFaCodes = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackTitle = widget.entry.username.isNotEmpty
        ? widget.entry.username
        : (widget.entry.title?.isNotEmpty ?? false)
            ? widget.entry.title!
            : 'Password entry';
    final title = (widget.entry.title ?? '').isNotEmpty ? widget.entry.title! : fallbackTitle;
    final subtitleParts = <String>[];
    if ((widget.entry.alias ?? '').isNotEmpty) subtitleParts.add(widget.entry.alias!);
    if (widget.entry.username.isNotEmpty && widget.entry.username != title) {
      subtitleParts.add(widget.entry.username);
    }
    if (widget.entry.email.isNotEmpty) subtitleParts.add(widget.entry.email);
    final subtitle = subtitleParts.join(' • ');
    final created = _formatTimestamp(widget.entry.createdAt);
    final updated = _formatTimestamp(widget.entry.updatedAt);
    final passwordUpdated = _formatTimestamp(widget.entry.passwordLastChangedAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                IconButton(onPressed: widget.onEdit, icon: const Icon(Icons.edit)),
                IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
            if ((widget.entry.website ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(widget.entry.website!, style: theme.textTheme.bodySmall),
            ],
            if ((widget.entry.category ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Category: ${widget.entry.category}', style: theme.textTheme.bodySmall),
              ),
            if ((widget.entry.hint ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Hint: ${widget.entry.hint}', style: theme.textTheme.bodySmall),
              ),
            if ((widget.entry.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.entry.description!, style: theme.textTheme.bodyMedium),
              ),
            if (widget.entry.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.entry.tags.map((tag) => Chip(label: Text(tag))).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Text('Encrypted password:', style: theme.textTheme.bodySmall),
            SelectableText(widget.entry.encryptedPassword, style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            if (_revealed && _plainPassword != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Decrypted password:', style: theme.textTheme.bodySmall),
                  SelectableText(
                    _plainPassword!,
                    style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_plainTwoFaCodes != null) ...[
                    const SizedBox(height: 8),
                    Text('2FA backup codes:', style: theme.textTheme.bodySmall),
                    SelectableText(_plainTwoFaCodes!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            if (widget.entry.isTwoFaEnabled || widget.entry.twoFaType != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.security, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      widget.entry.isTwoFaEnabled
                          ? '2FA enabled${widget.entry.twoFaType != null ? ' (${widget.entry.twoFaType})' : ''}'
                          : '2FA disabled',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (passwordUpdated != null || updated != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (passwordUpdated != null)
                      Text('Password updated: $passwordUpdated', style: theme.textTheme.labelSmall),
                    if (updated != null)
                      Text('Modified: $updated', style: theme.textTheme.labelSmall),
                    if (created != null && created != updated)
                      Text('Created: $created', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleReveal,
                  icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
                  label: Text(_revealed ? 'Hide' : 'Reveal'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: widget.onShare,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordEntrySheet extends StatefulWidget {
  const PasswordEntrySheet({super.key, required this.encryptionService, this.entry});

  final EncryptionService encryptionService;
  final PasswordEntry? entry;

  @override
  State<PasswordEntrySheet> createState() => _PasswordEntrySheetState();
}

class _PasswordEntrySheetState extends State<PasswordEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController = TextEditingController(text: widget.entry?.title ?? '');
  late final TextEditingController _usernameController = TextEditingController(text: widget.entry?.username ?? '');
  late final TextEditingController _emailController = TextEditingController(text: widget.entry?.email ?? '');
  late final TextEditingController _websiteController = TextEditingController(text: widget.entry?.website ?? '');
  late final TextEditingController _aliasController = TextEditingController(text: widget.entry?.alias ?? '');
  late final TextEditingController _categoryController = TextEditingController(text: widget.entry?.category ?? '');
  late final TextEditingController _hintController = TextEditingController(text: widget.entry?.hint ?? '');
  late final TextEditingController _descriptionController = TextEditingController(text: widget.entry?.description ?? '');
  late final TextEditingController _tagsController = TextEditingController(
    text: widget.entry != null && widget.entry!.tags.isNotEmpty ? widget.entry!.tags.join(', ') : '',
  );
  late final TextEditingController _passwordController = TextEditingController();
  late final TextEditingController _twoFaTypeController = TextEditingController(text: widget.entry?.twoFaType ?? '');
  late final TextEditingController _twoFaBackupController = TextEditingController(
    text: widget.entry?.twoFaBackupCodes != null ? '********' : '',
  );
  bool _isTwoFaEnabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isTwoFaEnabled = widget.entry?.isTwoFaEnabled ?? false;
    if (widget.entry != null) {
      _passwordController.text = '********';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final nowIso = DateTime.now().toIso8601String();
    final isPasswordPlaceholder = widget.entry != null && _passwordController.text == '********';
    final passwordText = isPasswordPlaceholder ? null : _passwordController.text.trim();

    PasswordEntry newEntry = widget.entry ?? PasswordEntry.create();

    if (passwordText != null && passwordText.isNotEmpty) {
      final payload = await widget.encryptionService.encrypt(passwordText);
      newEntry = newEntry.copyWith(
        encryptedPassword: payload.cipherText,
        iv: payload.iv,
        passwordLastChangedAt: nowIso,
      );
    }

    String? twoFaBackupCipher = widget.entry?.twoFaBackupCodes;
    String? twoFaBackupIv = widget.entry?.twoFaBackupIv;
    final backupField = _twoFaBackupController.text;
    final isBackupPlaceholder = widget.entry != null && backupField == '********';
    if (!isBackupPlaceholder) {
      final trimmed = backupField.trim();
      if (trimmed.isEmpty) {
        twoFaBackupCipher = null;
        twoFaBackupIv = null;
      } else {
        final payload = await widget.encryptionService.encrypt(trimmed);
        twoFaBackupCipher = payload.cipherText;
        twoFaBackupIv = payload.iv;
      }
    }

    if (!_isTwoFaEnabled) {
      twoFaBackupCipher = null;
      twoFaBackupIv = null;
    }

    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((element) => element.isNotEmpty)
        .toList();

    final createdAt = widget.entry?.createdAt ?? newEntry.createdAt ?? nowIso;

    newEntry = newEntry.copyWith(
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      alias: _aliasController.text.trim().isEmpty ? null : _aliasController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      hint: _hintController.text.trim().isEmpty ? null : _hintController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      tags: tags,
      isTwoFaEnabled: _isTwoFaEnabled,
      twoFaType: !_isTwoFaEnabled || _twoFaTypeController.text.trim().isEmpty
          ? null
          : _twoFaTypeController.text.trim(),
      twoFaBackupCodes: twoFaBackupCipher,
      twoFaBackupIv: twoFaBackupIv,
      createdAt: createdAt,
      updatedAt: nowIso,
    );

    if (!mounted) return;
    Navigator.pop(context, newEntry);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.entry == null ? 'New password' : 'Update password',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(labelText: 'Website (optional)'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _aliasController,
                decoration: const InputDecoration(labelText: 'Alias (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.entry == null ? 'Password' : 'Password (type to change)',
                ),
                validator: (value) {
                  if (widget.entry == null && (value == null || value.isEmpty)) {
                    return 'Password is required for new entries';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _hintController,
                decoration: const InputDecoration(labelText: 'Hint'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  helperText: 'Comma separated values',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isTwoFaEnabled,
                onChanged: (value) => setState(() => _isTwoFaEnabled = value),
                title: const Text('Two-factor authentication enabled'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_isTwoFaEnabled) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _twoFaTypeController,
                  decoration: const InputDecoration(labelText: '2FA type (e.g. TOTP)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _twoFaBackupController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '2FA backup codes',
                    helperText: 'Type to add or replace encrypted backup codes',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class SecureTokenStore {
  static const _tokenKey = 'master_token';
  static const _pinKey = 'master_pin';
  final FlutterSecureStorage? _storage = kIsWeb ? null : const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      return;
    }
    await _storage!.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
    return _storage!.read(key: _tokenKey);
  }

  Future<bool> hasToken() async => (await readToken()) != null;

  Future<void> savePin(String pin) async {
    final hashed = _hash(pin.trim());
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinKey, hashed);
      return;
    }
    await _storage!.write(key: _pinKey, value: hashed);
  }

  Future<bool> hasPin() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_pinKey);
    }
    return (await _storage!.read(key: _pinKey)) != null;
  }

  Future<bool> verifyPin(String pin) async {
    final hashed = _hash(pin.trim());
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_pinKey);
      if (stored == null) return false;
      return stored == hashed;
    }
    final stored = await _storage!.read(key: _pinKey);
    if (stored == null) return false;
    return stored == hashed;
  }

  String _hash(String value) => crypto.sha256.convert(utf8.encode(value)).toString();
}

class EncryptionService {
  EncryptionService._(this._key);

  final encrypt_pkg.Key _key;

  static Future<EncryptionService> fromToken(String token) async {
    final derivator = cryptography.Pbkdf2(
      macAlgorithm: cryptography.Hmac.sha256(),
      iterations: 20000,
      bits: 256,
    );
    final secretKey = await derivator.deriveKey(
      secretKey: cryptography.SecretKey(utf8.encode(token)),
      nonce: utf8.encode('password_manager_salt'),
    );
    final keyBytes = await secretKey.extractBytes();
    return EncryptionService._(encrypt_pkg.Key(Uint8List.fromList(keyBytes)));
  }

  Future<EncryptedPayload> encrypt(String plainText) async {
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    final aes = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(
        _key,
        mode: encrypt_pkg.AESMode.cbc,
        padding: 'PKCS7',
      ),
    );
    final encrypted = aes.encrypt(plainText, iv: iv);
    return EncryptedPayload(cipherText: encrypted.base64, iv: iv.base64);
  }

  String decrypt(EncryptedPayload payload) {
    final iv = encrypt_pkg.IV.fromBase64(payload.iv);
    final aes = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(_key, mode: encrypt_pkg.AESMode.cbc, padding: 'PKCS7'),
    );
    return aes.decrypt64(payload.cipherText, iv: iv);
  }
}

class EncryptedPayload {
  const EncryptedPayload({required this.cipherText, required this.iv});

  final String cipherText;
  final String iv;
}

class PasswordEntry {
  PasswordEntry({
    required this.id,
    required this.username,
    required this.email,
    required this.encryptedPassword,
    required this.iv,
    this.title,
    this.website,
    this.alias,
    this.category,
    this.hint,
    this.description,
    List<String>? tags,
    this.isTwoFaEnabled = false,
    this.twoFaType,
    this.twoFaBackupCodes,
    this.twoFaBackupIv,
    this.passwordLastChangedAt,
    this.createdAt,
    this.updatedAt,
  }) : tags = tags ?? const [];

  factory PasswordEntry.create() => PasswordEntry(
        id: const Uuid().v4(),
        username: '',
        email: '',
        encryptedPassword: '',
        iv: '',
        tags: const [],
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        encryptedPassword: json['encryptedPassword'] as String,
        iv: json['iv'] as String,
        title: json['title'] as String?,
        website: json['website'] as String?,
        alias: json['alias'] as String?,
        category: json['category'] as String?,
        hint: json['hint'] as String?,
        description: json['description'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
        isTwoFaEnabled: json['is_2fa_enabled'] as bool? ?? false,
        twoFaType: json['two_fa_type'] as String?,
        twoFaBackupCodes: json['two_fa_backup_codes'] as String?,
        twoFaBackupIv: json['two_fa_backup_iv'] as String?,
        passwordLastChangedAt: json['password_last_changed_at'] as String?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  final String id;
  final String username;
  final String email;
  final String encryptedPassword;
  final String iv;
  final String? title;
  final String? website;
  final String? alias;
  final String? category;
  final String? hint;
  final String? description;
  final List<String> tags;
  final bool isTwoFaEnabled;
  final String? twoFaType;
  final String? twoFaBackupCodes;
  final String? twoFaBackupIv;
  final String? passwordLastChangedAt;
  final String? createdAt;
  final String? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'encryptedPassword': encryptedPassword,
        'iv': iv,
        'title': title,
        'website': website,
        'alias': alias,
        'category': category,
        'hint': hint,
        'description': description,
        'tags': tags,
        'is_2fa_enabled': isTwoFaEnabled,
        'two_fa_type': twoFaType,
        'two_fa_backup_codes': twoFaBackupCodes,
        'two_fa_backup_iv': twoFaBackupIv,
        'password_last_changed_at': passwordLastChangedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  PasswordEntry copyWith({
    String? username,
    String? email,
    String? encryptedPassword,
    String? iv,
    String? title,
    String? website,
    String? alias,
    String? category,
    String? hint,
    String? description,
    List<String>? tags,
    bool? isTwoFaEnabled,
    String? twoFaType,
    String? twoFaBackupCodes,
    String? twoFaBackupIv,
    String? passwordLastChangedAt,
    String? createdAt,
    String? updatedAt,
  }) {
    return PasswordEntry(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      iv: iv ?? this.iv,
      title: title ?? this.title,
      website: website ?? this.website,
      alias: alias ?? this.alias,
      category: category ?? this.category,
      hint: hint ?? this.hint,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      isTwoFaEnabled: isTwoFaEnabled ?? this.isTwoFaEnabled,
      twoFaType: twoFaType ?? this.twoFaType,
      twoFaBackupCodes: twoFaBackupCodes ?? this.twoFaBackupCodes,
      twoFaBackupIv: twoFaBackupIv ?? this.twoFaBackupIv,
      passwordLastChangedAt: passwordLastChangedAt ?? this.passwordLastChangedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PasswordRepository {
  static const _storageKey = 'password_entries';

  Future<List<PasswordEntry>> fetchEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data == null) return [];
    final decoded = jsonDecode(data) as List<dynamic>;
    return decoded.map((e) => PasswordEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveEntries(List<PasswordEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
