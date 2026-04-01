import 'dart:convert';
import 'dart:io';
import 'package:open_wearables_health_sdk/open_wearables_health_sdk.dart';
import 'package:open_wearables_health_sdk/health_data_type.dart';
import 'package:open_wearables_health_sdk/open_wearables_health_sdk_method_channel.dart';
import 'package:http/http.dart' as http;

class HealthService {
  static const String _host = 'https://backend-production-07b2.up.railway.app';

  bool _initialized = false;

  /// Initialize the SDK and configure the host
  Future<void> initialize() async {
    if (_initialized) return;

    await OpenWearablesHealthSdk.configure(host: _host);
    _initialized = true;
  }

  /// Whether the user is signed in to Open Wearables
  bool get isSignedIn => OpenWearablesHealthSdk.isSignedIn;

  /// Whether background sync is currently active
  bool get isSyncing => OpenWearablesHealthSdk.isSyncActive;

  /// Connect using an invitation code from the Open Wearables dashboard.
  /// Returns null on success, or an error message string on failure.
  Future<String?> connectWithInvitationCode(String code) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // Redeem the invitation code through the backend API
      final response = await http.post(
        Uri.parse('$_host/api/v1/invitation-code/redeem'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': code}),
      );

      if (response.statusCode != 200) {
        final body = json.decode(response.body);
        return body['detail'] ?? 'Invalid invitation code';
      }

      final data = json.decode(response.body);

      await OpenWearablesHealthSdk.signIn(
        userId: data['userId'] ?? data['user_id'],
        accessToken: data['accessToken'] ?? data['access_token'],
        refreshToken: data['refreshToken'] ?? data['refresh_token'],
      );

      return null;
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  /// Request HealthKit permissions. Returns true if granted.
  Future<bool> requestPermissions() async {
    try {
      final authorized = await OpenWearablesHealthSdk.requestAuthorization(
        types: [
          HealthDataType.steps,
          HealthDataType.heartRate,
          HealthDataType.restingHeartRate,
          HealthDataType.heartRateVariabilitySDNN,
          HealthDataType.oxygenSaturation,
          HealthDataType.respiratoryRate,
          HealthDataType.bodyMass,
          HealthDataType.bodyFatPercentage,
          HealthDataType.sleep,
          HealthDataType.workout,
          HealthDataType.activeEnergy,
          HealthDataType.basalEnergy,
          HealthDataType.vo2Max,
          HealthDataType.bloodPressureSystolic,
          HealthDataType.bloodPressureDiastolic,
          HealthDataType.bloodGlucose,
        ],
      );
      return authorized;
    } catch (e) {
      print('[HealthService] Permission request failed: $e');
      return false;
    }
  }

  /// Start background sync. Returns true on success.
  Future<bool> startSync() async {
    try {
      if (Platform.isAndroid) {
        final providers = await OpenWearablesHealthSdk.getAvailableProviders();
        if (providers.contains(AndroidHealthProvider.healthConnect)) {
          await OpenWearablesHealthSdk.setProvider(
              AndroidHealthProvider.healthConnect);
        } else if (providers.contains(AndroidHealthProvider.samsungHealth)) {
          await OpenWearablesHealthSdk.setProvider(
              AndroidHealthProvider.samsungHealth);
        }
      }

      await OpenWearablesHealthSdk.startBackgroundSync();
      // Check sync status
      print('Sync active: ${OpenWearablesHealthSdk.isSyncActive}');
      return true;
    } catch (e) {
      print('[HealthService] Start sync failed: $e');
      return false;
    }
  }

  /// Trigger an immediate sync
  Future<void> syncNow() async {
    try {
      await OpenWearablesHealthSdk.syncNow();
    } catch (e) {
      print('[HealthService] Sync now failed: $e');
    }
  }

  /// Reset all anchors and re-export all health data from scratch
  Future<void> resyncAll() async {
    try {
      await OpenWearablesHealthSdk.resetAnchors();
      await OpenWearablesHealthSdk.syncNow();
    } catch (e) {
      print('[HealthService] Resync all failed: $e');
    }
  }

  /// Sign out and stop syncing
  Future<void> signOut() async {
    try {
      await OpenWearablesHealthSdk.stopBackgroundSync();
      await OpenWearablesHealthSdk.signOut();
    } catch (e) {
      print('[HealthService] Sign out failed: $e');
    }
  }
}
