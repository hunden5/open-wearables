import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'services/health_service.dart';
import 'package:open_wearables_health_sdk/open_wearables_health_sdk_method_channel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HealthService().initialize();
  runApp(const VitalSyncApp());
}

class VitalSyncApp extends StatelessWidget {
  const VitalSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VitalSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          surface: const Color(0xFF0A0A0F),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _health = HealthService();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  bool _isError = false;
@override
void initState() {
  super.initState();
  _checkExistingSession();
  _setupSDKLogging();
}

void _setupSDKLogging() {
  // Listen to SDK logs
  MethodChannelOpenWearablesHealthSdk.logStream.listen((message) {
    print('[HealthSDK] $message');
  });

  // Listen to auth errors
  MethodChannelOpenWearablesHealthSdk.authErrorStream.listen((error) {
    print('[HealthSDK] Auth error: ${error['statusCode']} - ${error['message']}');
  });
  
  // Log current state using HealthService
  print('Is signed in: ${_health.isSignedIn}');
  print('Is syncing: ${_health.isSyncing}');
}

@override
void dispose() {
  _codeController.dispose();
  super.dispose();
}

  void _checkExistingSession() {
    setState(() {});
  }

  void _setStatus(String message, {bool error = false}) {
    setState(() {
      _statusMessage = message;
      _isError = error;
    });
  }

  Future<void> _connect() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _setStatus('Please enter your invitation code', error: true);
      return;
    }

    setState(() => _isLoading = true);
    _setStatus('Connecting...');

    final error = await _health.connectWithInvitationCode(code);

    if (error != null) {
      _setStatus(error, error: true);
      setState(() => _isLoading = false);
      return;
    }

    _setStatus('Requesting health permissions...');
    final authorized = await _health.requestPermissions();

    if (!authorized) {
      _setStatus('Health access denied. You can change this in Settings > Health > VitalSync.', error: true);
      setState(() => _isLoading = false);
      return;
    }

    _setStatus('Starting background sync...');
    final started = await _health.startSync();

    setState(() => _isLoading = false);

    if (started) {
      _setStatus('VitalSync is active and syncing your health data.');
    } else {
      _setStatus('Connected but sync could not start. Try tapping Sync Now.', error: true);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isLoading = true);
    _setStatus('Syncing...');
    await _health.syncNow();
    setState(() => _isLoading = false);
    _setStatus('Sync triggered successfully.');
  }

  Future<void> _resyncAll() async {
    setState(() => _isLoading = true);
    _setStatus('Re-exporting all health data...');
    await _health.resyncAll();
    setState(() => _isLoading = false);
    _setStatus('Full re-sync started. This may take a few minutes.');
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    await _health.signOut();
    _codeController.clear();
    setState(() => _isLoading = false);
    _setStatus('Disconnected.');
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = _health.isSignedIn;
    final isSyncing = _health.isSyncing;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(isSyncing),
              const SizedBox(height: 40),
              _buildStatusCard(isSignedIn, isSyncing),
              const SizedBox(height: 32),
              if (!isSignedIn) _buildConnectSection(),
              if (isSignedIn) _buildActionsSection(isSyncing),
              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildStatusMessage(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSyncing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Text(
              'VitalSync',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Your biomarker intelligence platform',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(bool isSignedIn, bool isSyncing) {
    final statusColor = isSyncing
        ? const Color(0xFF4ADE80)
        : isSignedIn
            ? const Color(0xFFFBBF24)
            : const Color(0xFF71717A);

    final statusText = isSyncing
        ? 'Syncing Active'
        : isSignedIn
            ? 'Connected, sync paused'
            : 'Not Connected';

    final statusSubtext = isSyncing
        ? 'Health data is syncing in the background'
        : isSignedIn
            ? 'Tap Start Sync to begin'
            : 'Connect to start syncing your health data';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.15),
            ),
            child: Icon(
              isSyncing ? Icons.sync : isSignedIn ? Icons.pause_circle : Icons.link_off,
              color: statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusSubtext,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const CupertinoActivityIndicator(color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildConnectSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONNECT',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF71717A),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: TextField(
            controller: _codeController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Invitation code',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: Icon(CupertinoIcons.ticket, color: Colors.white.withValues(alpha: 0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            autocorrect: false,
            onSubmitted: (_) => _connect(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _connect,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              'Connect to VitalSync',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(bool isSyncing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACTIONS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF71717A),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: Column(
            children: [
              _buildActionTile(
                icon: isSyncing ? Icons.pause : Icons.play_arrow,
                iconColor: const Color(0xFF4ADE80),
                title: isSyncing ? 'Stop Sync' : 'Start Sync',
                subtitle: isSyncing ? 'Pause background syncing' : 'Begin syncing health data',
                onTap: isSyncing ? _disconnect : _syncNow,
              ),
              const Divider(height: 1, color: Color(0xFF27272A), indent: 60),
              _buildActionTile(
                icon: Icons.refresh,
                iconColor: const Color(0xFF6366F1),
                title: 'Sync Now',
                subtitle: 'Force an immediate sync',
                onTap: _syncNow,
              ),
              const Divider(height: 1, color: Color(0xFF27272A), indent: 60),
              _buildActionTile(
                icon: Icons.cloud_sync,
                iconColor: const Color(0xFFF59E0B),
                title: 'Resync All Data',
                subtitle: 'Re-export all health data from scratch',
                onTap: _resyncAll,
              ),
              const Divider(height: 1, color: Color(0xFF27272A), indent: 60),
              _buildActionTile(
                icon: Icons.logout,
                iconColor: const Color(0xFFEF4444),
                title: 'Disconnect',
                subtitle: 'Sign out and stop syncing',
                onTap: _disconnect,
                destructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: destructive ? const Color(0xFFEF4444) : Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: Colors.white.withValues(alpha: 0.2),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    final color = _isError ? const Color(0xFFEF4444) : const Color(0xFF4ADE80);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            _isError ? CupertinoIcons.exclamationmark_circle : CupertinoIcons.checkmark_circle,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
