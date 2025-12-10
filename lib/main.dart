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

  static const _primaryColor = Color(0xFF6366F1);
  static const _secondaryColor = Color(0xFF8B5CF6);
  static const _surfaceColor = Color(0xFFF8FAFC);
  static const _cardColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
      primary: _primaryColor,
      secondary: _secondaryColor,
      surface: _surfaceColor,
    );

    final theme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _surfaceColor,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 32),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 24),
        headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: GoogleFonts.inter(fontSize: 16),
        bodyMedium: GoogleFonts.inter(fontSize: 14),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        labelSmall: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.grey[900],
        ),
        iconTheme: IconThemeData(color: Colors.grey[800]),
      ),
      cardTheme: CardThemeData(
        color: _cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.grey.shade300),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey[100],
        selectedColor: _primaryColor.withOpacity(0.15),
        labelStyle: GoogleFonts.inter(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
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
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.08),
              theme.colorScheme.surface,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield_rounded, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 32),
                Text(
                  'Secure Your Vault',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a master token to encrypt all your passwords. Add an optional PIN for quick access.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.key_rounded, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('Master Token', style: theme.textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _tokenController,
                            decoration: const InputDecoration(
                              labelText: 'Enter master token',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            obscureText: true,
                            validator: (value) => value == null || value.trim().isEmpty ? 'Token is required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmTokenController,
                            decoration: const InputDecoration(
                              labelText: 'Confirm master token',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
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
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.pin_rounded, color: theme.colorScheme.secondary, size: 20),
                              const SizedBox(width: 8),
                              Text('Quick PIN', style: theme.textTheme.titleMedium),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Optional', style: theme.textTheme.labelSmall),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pinController,
                            decoration: const InputDecoration(
                              labelText: 'PIN (4-8 digits)',
                              prefixIcon: Icon(Icons.dialpad_rounded),
                            ),
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 8,
                          ),
                          TextFormField(
                            controller: _confirmPinController,
                            decoration: const InputDecoration(
                              labelText: 'Confirm PIN',
                              prefixIcon: Icon(Icons.dialpad_rounded),
                            ),
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
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _submit,
                              icon: _saving
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_rounded),
                              label: const Text('Create Vault'),
                            ),
                          ),
                        ],
                      ),
                    ),
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
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.05),
              theme.colorScheme.secondary.withOpacity(0.08),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_rounded, size: 56, color: Colors.white),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Welcome Back',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.hasPin
                            ? 'Enter your PIN to unlock your vault'
                            : 'Use biometrics or continue to access your passwords',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      if (widget.hasPin) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _pinController,
                                  decoration: InputDecoration(
                                    labelText: 'PIN',
                                    errorText: _error,
                                    prefixIcon: const Icon(Icons.dialpad_rounded),
                                  ),
                                  keyboardType: TextInputType.number,
                                  obscureText: true,
                                  maxLength: 8,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: _verifyingPin ? null : _unlockWithPin,
                                    icon: _verifyingPin
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.lock_open_rounded),
                                    label: const Text('Unlock'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _verifyingPin ? null : _unlockWithPin,
                            icon: _verifyingPin
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Continue'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_biometricsAvailable)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _authenticateBiometric,
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text('Use Biometrics'),
                          ),
                        )
                      else if (!_checkingBiometrics && !kIsWeb)
                        TextButton.icon(
                          onPressed: _prepareBiometrics,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Check biometrics'),
                        ),
                    ],
                  ),
                ),
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
    if (_encryptionService == null) return;
    
    // Encrypt all sensitive fields
    final encryptedUsername = entry.username.isNotEmpty 
        ? await _encryptionService!.encrypt(entry.username) : null;
    final encryptedEmail = entry.email.isNotEmpty 
        ? await _encryptionService!.encrypt(entry.email) : null;
    final encryptedTitle = (entry.title ?? '').isNotEmpty 
        ? await _encryptionService!.encrypt(entry.title!) : null;
    final encryptedWebsite = (entry.website ?? '').isNotEmpty 
        ? await _encryptionService!.encrypt(entry.website!) : null;
    final encryptedAlias = (entry.alias ?? '').isNotEmpty 
        ? await _encryptionService!.encrypt(entry.alias!) : null;
    final encryptedCategory = (entry.category ?? '').isNotEmpty 
        ? await _encryptionService!.encrypt(entry.category!) : null;
    final encryptedHint = (entry.hint ?? '').isNotEmpty 
        ? await _encryptionService!.encrypt(entry.hint!) : null;
    final encryptedDescription = (entry.description ?? '').isNotEmpty 
        ? await _encryptionService!.encrypt(entry.description!) : null;
    final encryptedTags = entry.tags.isNotEmpty 
        ? await _encryptionService!.encrypt(entry.tags.join('|')) : null;
    final encryptedTwoFaType = (entry.twoFaType ?? '').isNotEmpty 
        ? await _encryptionService!.encrypt(entry.twoFaType!) : null;
    
    final payload = {
      'v': 2, // Version 2 = fully encrypted
      'id': entry.id,
      'u': encryptedUsername != null ? '${encryptedUsername.cipherText}:${encryptedUsername.iv}' : null,
      'e': encryptedEmail != null ? '${encryptedEmail.cipherText}:${encryptedEmail.iv}' : null,
      'p': '${entry.encryptedPassword}:${entry.iv}',
      't': encryptedTitle != null ? '${encryptedTitle.cipherText}:${encryptedTitle.iv}' : null,
      'w': encryptedWebsite != null ? '${encryptedWebsite.cipherText}:${encryptedWebsite.iv}' : null,
      'a': encryptedAlias != null ? '${encryptedAlias.cipherText}:${encryptedAlias.iv}' : null,
      'c': encryptedCategory != null ? '${encryptedCategory.cipherText}:${encryptedCategory.iv}' : null,
      'h': encryptedHint != null ? '${encryptedHint.cipherText}:${encryptedHint.iv}' : null,
      'd': encryptedDescription != null ? '${encryptedDescription.cipherText}:${encryptedDescription.iv}' : null,
      'tg': encryptedTags != null ? '${encryptedTags.cipherText}:${encryptedTags.iv}' : null,
      '2fa': entry.isTwoFaEnabled,
      '2ft': encryptedTwoFaType != null ? '${encryptedTwoFaType.cipherText}:${encryptedTwoFaType.iv}' : null,
      '2fb': entry.twoFaBackupCodes != null ? '${entry.twoFaBackupCodes}:${entry.twoFaBackupIv}' : null,
    };
    
    // Remove null values to minimize size
    payload.removeWhere((key, value) => value == null);
    
    // Encode to base64 (no compression - encrypted data doesn't compress well)
    final jsonBytes = utf8.encode(jsonEncode(payload));
    final base64String = base64Url.encode(jsonBytes);
    
    // Add prefix for identification
    final shareCode = 'PM2:$base64String';
    
    await Share.share(shareCode);
  }

  Future<void> _importSharedPayload() async {
    if (_encryptionService == null) return;
    final controller = TextEditingController();
    final payloadText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.download_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Text('Import Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste the shared code (starts with PM2:)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'PM2:H4sIAAAA...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Import')),
        ],
      ),
    );
    if (payloadText == null || payloadText.isEmpty) return;
    
    try {
      Map<String, dynamic> decoded;
      bool isV2 = false;
      
      // Check for new format (PM2:base64)
      if (payloadText.startsWith('PM2:')) {
        isV2 = true;
        final base64Part = payloadText.substring(4);
        final jsonBytes = base64Url.decode(base64Part);
        decoded = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
      } else {
        // Legacy JSON format
        final normalized = _extractJsonBlock(payloadText);
        decoded = jsonDecode(normalized) as Map<String, dynamic>;
      }
      
      final nowIso = DateTime.now().toIso8601String();
      
      String decryptField(String? encryptedField) {
        if (encryptedField == null || encryptedField.isEmpty) return '';
        final parts = encryptedField.split(':');
        if (parts.length != 2) return '';
        return _encryptionService!.decrypt(
          EncryptedPayload(cipherText: parts[0], iv: parts[1]),
        );
      }
      
      String username, email, encryptedPassword, iv;
      String? title, website, alias, category, hint, description, twoFaType;
      String? twoFaBackupCodes, twoFaBackupIv;
      List<String> tags = [];
      bool isTwoFaEnabled = false;
      
      if (isV2 && decoded['v'] == 2) {
        // Decrypt all fields from v2 format
        username = decryptField(decoded['u'] as String?);
        email = decryptField(decoded['e'] as String?);
        
        final passwordParts = (decoded['p'] as String).split(':');
        encryptedPassword = passwordParts[0];
        iv = passwordParts[1];
        
        title = decryptField(decoded['t'] as String?);
        if (title!.isEmpty) title = null;
        website = decryptField(decoded['w'] as String?);
        if (website!.isEmpty) website = null;
        alias = decryptField(decoded['a'] as String?);
        if (alias!.isEmpty) alias = null;
        category = decryptField(decoded['c'] as String?);
        if (category!.isEmpty) category = null;
        hint = decryptField(decoded['h'] as String?);
        if (hint!.isEmpty) hint = null;
        description = decryptField(decoded['d'] as String?);
        if (description!.isEmpty) description = null;
        
        final tagsDecrypted = decryptField(decoded['tg'] as String?);
        if (tagsDecrypted.isNotEmpty) {
          tags = tagsDecrypted.split('|').where((t) => t.isNotEmpty).toList();
        }
        
        isTwoFaEnabled = decoded['2fa'] as bool? ?? false;
        twoFaType = decryptField(decoded['2ft'] as String?);
        if (twoFaType!.isEmpty) twoFaType = null;
        
        final backupField = decoded['2fb'] as String?;
        if (backupField != null && backupField.isNotEmpty) {
          final backupParts = backupField.split(':');
          twoFaBackupCodes = backupParts[0];
          twoFaBackupIv = backupParts.length > 1 ? backupParts[1] : null;
        }
      } else {
        // Legacy format
        username = decoded['username'] as String? ?? '';
        email = decoded['email'] as String? ?? '';
        encryptedPassword = decoded['cipher'] as String;
        iv = decoded['iv'] as String;
        title = decoded['title'] as String?;
        website = decoded['website'] as String?;
        alias = decoded['alias'] as String?;
        category = decoded['category'] as String?;
        hint = decoded['hint'] as String?;
        description = decoded['description'] as String?;
        
        final rawTags = decoded['tags'];
        if (rawTags is List) {
          tags = rawTags.map((e) => e.toString()).toList();
        } else if (rawTags is String) {
          tags = rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        
        isTwoFaEnabled = decoded['is_2fa_enabled'] as bool? ?? false;
        twoFaType = decoded['two_fa_type'] as String?;
        twoFaBackupCodes = decoded['two_fa_backup_codes'] as String?;
        twoFaBackupIv = decoded['two_fa_backup_iv'] as String?;
      }
      
      final entry = PasswordEntry(
        id: decoded['id'] as String? ?? const Uuid().v4(),
        username: username,
        email: email,
        encryptedPassword: encryptedPassword,
        iv: iv,
        title: title,
        website: website,
        alias: alias,
        category: category,
        hint: hint,
        description: description,
        tags: tags,
        isTwoFaEnabled: isTwoFaEnabled,
        twoFaType: twoFaType,
        twoFaBackupCodes: twoFaBackupCodes,
        twoFaBackupIv: twoFaBackupIv,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.green),
              ),
              const SizedBox(width: 12),
              const Text('Import Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Password decrypted successfully!', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(decrypted, style: const TextStyle(fontFamily: 'monospace')),
              ),
            ],
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
    } catch (error, stack) {
      debugPrint('Import failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: ${error.runtimeType}'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Vault',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Import password',
            onPressed: _importSharedPayload,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.download_rounded, color: theme.colorScheme.primary, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Lock vault',
            onPressed: () async {
              final navigator = Navigator.of(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lock_rounded, color: Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      const Text('Lock Vault?'),
                    ],
                  ),
                  content: const Text('Your vault will be locked and you\'ll need to enter your PIN or use biometrics to unlock.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lock')),
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
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.orange, size: 20),
            ),
          ),
          const SizedBox(width: 12),
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
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Password'),
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
    final updated = _formatTimestamp(widget.entry.updatedAt);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _toggleReveal,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.15),
                          theme.colorScheme.secondary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(widget.entry.category),
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.entry.isTwoFaEnabled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('2FA', style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400]),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'edit') widget.onEdit();
                      if (value == 'delete') _confirmDelete();
                      if (value == 'share') widget.onShare();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 12), Text('Edit')])),
                      const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share_rounded, size: 18), SizedBox(width: 12), Text('Share')])),
                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: Colors.red), SizedBox(width: 12), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
              if ((widget.entry.website ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.link_rounded, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.entry.website!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.entry.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.entry.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(tag, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w500)),
                  )).toList(),
                ),
              ],
              if (_revealed && _plainPassword != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.key_rounded, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text('Password', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _plainPassword!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Password copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.copy_rounded, size: 16, color: theme.colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _plainPassword!,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (_plainTwoFaCodes != null) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.security_rounded, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text('2FA Backup Codes', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(_plainTwoFaCodes!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (updated != null)
                    Text('Updated $updated', style: theme.textTheme.labelSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _toggleReveal,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: Icon(_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                    label: Text(_revealed ? 'Hide' : 'Reveal'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    final cat = (category ?? '').toLowerCase();
    if (cat.contains('social')) return Icons.people_rounded;
    if (cat.contains('bank') || cat.contains('finance')) return Icons.account_balance_rounded;
    if (cat.contains('email') || cat.contains('mail')) return Icons.email_rounded;
    if (cat.contains('work') || cat.contains('office')) return Icons.work_rounded;
    if (cat.contains('shop') || cat.contains('store')) return Icons.shopping_bag_rounded;
    if (cat.contains('game') || cat.contains('gaming')) return Icons.sports_esports_rounded;
    if (cat.contains('dev') || cat.contains('code')) return Icons.code_rounded;
    if (cat.contains('cloud') || cat.contains('storage')) return Icons.cloud_rounded;
    return Icons.key_rounded;
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Delete Password?'),
          ],
        ),
        content: const Text('This action cannot be undone. The password entry will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) widget.onDelete();
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
