import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:latlong2/latlong.dart';
import 'package:safechain/services/geofence_service.dart';
import 'package:safechain/services/notification_service.dart';

typedef GpsCallback = void Function(LatLng location);

class BleConnectionService {
  BleConnectionService._();
  static final BleConnectionService instance = BleConnectionService._();

  static const String _serviceUuid    = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String _txCharUuid     = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";
  static const int    _reconnectDelay = 5;

  BluetoothDevice? _device;
  StreamSubscription? _notifySubscription;
  StreamSubscription? _connectionSubscription;
  bool _running       = false;
  bool _reconnecting  = false;
  String? _btRemoteId;
  String? _deviceName;
  LatLng? lastLocation;

  // Optional callback so DeviceTrackingScreen can update its map in real-time
  GpsCallback? onLocationUpdate;

  // ── Start ────────────────────────────────────────────────────────
  Future<void> start(String btRemoteId, String deviceName) async {
    if (_running && _btRemoteId == btRemoteId) {
      if (lastLocation != null) {
        onLocationUpdate?.call(lastLocation!);
      }
      return;
    }
    _running    = true;
    _btRemoteId = btRemoteId;
    _deviceName = deviceName;

    await _initForegroundTask();
    await _connectAndListen();
  }

  // ── Stop ─────────────────────────────────────────────────────────
  Future<void> stop() async {
    _running = false;
    _reconnecting = false;
    GeofenceService.instance.reset();

    await _notifySubscription?.cancel();
    await _connectionSubscription?.cancel();
    _notifySubscription    = null;
    _connectionSubscription = null;

    try { await _device?.disconnect(); } catch (_) {}
    _device = null;

    await FlutterForegroundTask.stopService();
  }

  bool get isRunning => _running;

  // ── Foreground service (keeps Android alive in background) ───────
  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'safechain_ble',
        channelName: 'SafeChain Device Tracking',
        channelDescription: 'Keeps your SafeChain device connected in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );

    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'SafeChain Active',
        notificationText: 'Tracking ${_deviceName ?? "device"} in the background.',
        callback: _foregroundCallback,
      );
    } else {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'SafeChain Active',
        notificationText: 'Tracking ${_deviceName ?? "device"} in the background.',
      );
    }
  }

  // ── BLE connect + listen ──────────────────────────────────────────
  Future<void> _connectAndListen() async {
    if (!_running || _btRemoteId == null) return;

    try {
      _device = BluetoothDevice.fromId(_btRemoteId!);

      // Listen for disconnection → trigger auto-reconnect
      _connectionSubscription?.cancel();
      _connectionSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && _running && !_reconnecting) {
          _scheduleReconnect();
        }
      });

      await _device!.connect(timeout: const Duration(seconds: 15));

      final services = await _device!.discoverServices();

      final service = services.firstWhere(
            (s) => s.uuid.toString().toUpperCase() == _serviceUuid,
        orElse: () => throw Exception('SafeChain service not found'),
      );

      final characteristic = service.characteristics.firstWhere(
            (c) => c.uuid.toString().toUpperCase() == _txCharUuid,
        orElse: () => throw Exception('TX characteristic not found'),
      );

      if (!characteristic.isNotifying) {
        await characteristic.setNotifyValue(true);
      }

      _notifySubscription?.cancel();
      _notifySubscription = characteristic.lastValueStream.listen(_onData);

    } catch (e) {
      // Connection failed — schedule retry
      if (_running) _scheduleReconnect();
    }
  }

  // ── Parse incoming GPS bytes ──────────────────────────────────────
  void _onData(List<int> value) {
    try {
      final data = utf8.decode(value).trim();
      if (!data.contains(',')) return;
      final parts = data.split(',');
      if (parts.length != 2) return;
      final lat = double.tryParse(parts[0]);
      final lon = double.tryParse(parts[1]);
      if (lat == null || lon == null || lat == 0.0) return;

      final location = LatLng(lat, lon);
      lastLocation = location;

      // Notify any listening UI screen
      onLocationUpdate?.call(location);

      // Geofence check — fires notifications on boundary cross
      GeofenceService.instance.check(location);

    } catch (_) {}
  }

  // ── Auto-reconnect ────────────────────────────────────────────────
  void _scheduleReconnect() {
    if (!_running || _reconnecting) return;
    _reconnecting = true;
    Future.delayed(const Duration(seconds: _reconnectDelay), () async {
      _reconnecting = false;
      if (_running) await _connectAndListen();
    });
  }
}

// Required by flutter_foreground_task — must be a top-level function
@pragma('vm:entry-point')
void _foregroundCallback() {
}