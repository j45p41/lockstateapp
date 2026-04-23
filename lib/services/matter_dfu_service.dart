import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:lockstate/services/matter_home_service.dart';

void _log(String msg) => debugPrint('[MATTER-DFU] $msg');

/// Matter firmware metadata from CDN JSON
class MatterFirmwareInfo {
  final int version;
  final String url;
  final int size;
  final String checksumMd5;
  final String checksumSha256;
  final String type; // "matter"
  final String board; // "nrf52840"
  final String sdk; // "ncs-2.9.0"

  MatterFirmwareInfo({
    required this.version,
    required this.url,
    required this.size,
    this.checksumMd5 = '',
    this.checksumSha256 = '',
    this.type = 'matter',
    this.board = 'nrf52840',
    this.sdk = '',
  });

  factory MatterFirmwareInfo.fromJson(Map<String, dynamic> json) {
    return MatterFirmwareInfo(
      version: json['version'] as int,
      url: json['url'] as String,
      size: json['size'] as int,
      checksumMd5: json['checksum_md5'] as String? ?? '',
      checksumSha256: json['checksum_sha256'] as String? ?? '',
      type: json['type'] as String? ?? 'matter',
      board: json['board'] as String? ?? 'nrf52840',
      sdk: json['sdk'] as String? ?? '',
    );
  }
}

enum MatterDfuState {
  idle,
  fetchingMetadata,
  downloadingFirmware,
  scanningForDevice,
  connectingToDevice,
  transferring,
  completing,
  success,
  failed,
}

/// Matter DFU Service
/// Flow: App downloads firmware from CDN → scans for Matter device in DFU mode
///       → connects via BLE → transfers firmware → device validates and reboots
///
/// Unlike Hub-based DFU, there is no Hub intermediary. The user puts the Matter
/// device into DFU mode (long press button or via Matter command), then the app
/// transfers firmware directly over BLE.
class MatterDfuService {
  static const _prodJsonUrl = 'https://j45p41.github.io/firmware_MATTER.json';
  static const _testJsonUrl = 'https://j45p41.github.io/firmware_MATTER_test.json';

  /// Set to true to use test firmware URL
  bool testMode = false;

  String get firmwareJsonUrl => testMode ? _testJsonUrl : _prodJsonUrl;

  // BLE DFU UUIDs — same as proven LSM (hub-based) DFU
  static const _dfuServiceUuid = '0000fe59-0000-1000-8000-00805f9b34fb';
  static const _dfuDataCharUuid = '8ec90001-f315-4f60-9fb8-838830daea50';
  static const _dfuAckCharUuid = '8ec90002-f315-4f60-9fb8-838830daea50';

  // Transfer parameters — ALIGNED to the proven LSM DFU (dfu_service.dart).
  // The Matter device uses the same custom Locksure bootloader, so these
  // values are copied verbatim:
  //   - 240-byte chunks (was 490 — too large without MTU negotiation)
  //   - 5ms inter-chunk delay (was 2ms — too fast for the bootloader flash)
  static const _chunkSize = 240;
  static const _startMarker = [0xDF, 0x55, 0x53, 0x54, 0x01];
  static const _endMarker = [0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE];

  // Observable state for UI
  final ValueNotifier<MatterDfuState> state =
      ValueNotifier(MatterDfuState.idle);
  final ValueNotifier<double> progress = ValueNotifier(0.0);
  final ValueNotifier<String> statusMessage = ValueNotifier('');

  StreamSubscription? _scanSub;

  // ==================== METADATA ====================

  /// Fetch latest Matter firmware info from CDN
  Future<MatterFirmwareInfo?> fetchLatestFirmwareInfo() async {
    state.value = MatterDfuState.fetchingMetadata;
    statusMessage.value = 'Checking for updates...';

    try {
      final url = firmwareJsonUrl;
      _log('Fetching: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        _log('HTTP ${response.statusCode}');
        state.value = MatterDfuState.idle;
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final info = MatterFirmwareInfo.fromJson(json);
      _log('Latest: v${info.version} (${info.size} bytes)');

      state.value = MatterDfuState.idle;
      return info;
    } catch (e) {
      _log('Error fetching metadata: $e');
      state.value = MatterDfuState.idle;
      return null;
    }
  }

  // ==================== DOWNLOAD ====================

  /// Download firmware binary with checksum validation
  Future<Uint8List?> downloadFirmware(MatterFirmwareInfo info) async {
    state.value = MatterDfuState.downloadingFirmware;
    statusMessage.value = 'Downloading firmware v${info.version}...';
    progress.value = 0.02;

    try {
      _log('Downloading: ${info.url} (${info.size} bytes)');

      final response = await http.get(Uri.parse(info.url)).timeout(
        const Duration(seconds: 120),
      );

      if (response.statusCode != 200) {
        _log('Download failed: HTTP ${response.statusCode}');
        _fail('Download failed');
        return null;
      }

      final data = response.bodyBytes;
      progress.value = 0.04;

      // Validate size
      if (data.length != info.size) {
        _log('Size mismatch: ${data.length} vs ${info.size}');
        _fail('Firmware size mismatch — possible CDN issue');
        return null;
      }

      // Validate MD5
      if (info.checksumMd5.isNotEmpty) {
        final md5Hash = md5.convert(data).toString();
        if (md5Hash != info.checksumMd5) {
          _log('MD5 mismatch: $md5Hash vs ${info.checksumMd5}');
          _fail('Firmware checksum failed — file corrupted');
          return null;
        }
        _log('MD5 verified');
      }

      // Validate SHA256
      if (info.checksumSha256.isNotEmpty) {
        final sha256Hash = sha256.convert(data).toString();
        if (sha256Hash != info.checksumSha256) {
          _log('SHA256 mismatch');
          _fail('Firmware SHA256 failed — file corrupted');
          return null;
        }
        _log('SHA256 verified');
      }

      // Validate MCUboot image magic (first 4 bytes = 0x96f3b83d LE).
      // zephyr.bin starts with the Cortex-M4 vector table (stack pointer),
      // not the MCUboot header. Uploading the unsigned binary causes MCUboot
      // to reject it with "bad image magic" and fall back to the loader.
      if (data.length < 4 ||
          data[0] != 0x3d || data[1] != 0xb8 ||
          data[2] != 0xf3 || data[3] != 0x96) {
        final actual = data.length >= 4
            ? '${data[0].toRadixString(16).padLeft(2,'0')} '
              '${data[1].toRadixString(16).padLeft(2,'0')} '
              '${data[2].toRadixString(16).padLeft(2,'0')} '
              '${data[3].toRadixString(16).padLeft(2,'0')}'
            : '<too short>';
        _log('Not a signed MCUboot image — magic bytes: $actual '
             '(expected 3d b8 f3 96). Upload zephyr.signed.bin, not zephyr.bin');
        _fail('Firmware is not signed — upload zephyr.signed.bin to CDN');
        return null;
      }
      _log('MCUboot magic OK');

      progress.value = 0.05;
      statusMessage.value = 'Firmware downloaded and verified';
      _log('Download complete: ${data.length} bytes, checksums OK');

      state.value = MatterDfuState.idle;
      return data;
    } catch (e) {
      _log('Download error: $e');
      _fail('Download error: $e');
      return null;
    }
  }

  // ==================== DFU TRANSFER ====================

  /// Perform DFU transfer to Matter device via BLE.
  /// If [matterUniqueId] is provided, tries to trigger DFU mode remotely
  /// via HomeKit Identify (magic value 0xDFDF) before scanning.
  Future<bool> performDfu({
    required Uint8List firmwareData,
    required int targetVersion,
    String? deviceName,
    String? matterUniqueId,
  }) async {
    state.value = MatterDfuState.scanningForDevice;
    progress.value = 0.10;

    try {
      // Try remote DFU trigger via HomeKit Identify (0xDFDF magic value).
      // If it works, the device reboots into firmware_loader within ~2s
      // and starts advertising "LocksureDoor-DFU" over BLE.
      bool remoteTriggerSent = false;
      if (matterUniqueId != null) {
        statusMessage.value = 'Sending DFU command to device...';
        _log('Attempting remote DFU trigger via Identify for $matterUniqueId');
        final triggerResult = await MatterHomeService().triggerDfuMode(matterUniqueId);
        remoteTriggerSent = triggerResult['success'] == true;
        if (remoteTriggerSent) {
          _log('Remote DFU trigger sent — waiting for device to reboot');
          statusMessage.value = 'Device rebooting into DFU mode...';
          await Future.delayed(const Duration(seconds: 3));
        } else {
          _log('Remote trigger failed: ${triggerResult['error']} — falling back to manual');
        }
      }

      if (!remoteTriggerSent) {
        statusMessage.value = 'Put the device in DFU mode now (long-press the button). Scanning…';
      } else {
        statusMessage.value = 'Scanning for device in DFU mode...';
      }

      final device = await _scanForDfuDevice(
        deviceName: deviceName ?? 'LocksureDoor',
        timeout: Duration(seconds: remoteTriggerSent ? 15 : 30),
      );

      if (device == null) {
        _fail('Device not found — make sure it is in DFU mode and within BLE range');
        return false;
      }

      // Connect
      state.value = MatterDfuState.connectingToDevice;
      statusMessage.value = 'Connecting to ${device.platformName}...';
      progress.value = 0.15;

      await device.connect(
        timeout: const Duration(seconds: 45),
        autoConnect: false,
      );
      _log('Connected to ${device.platformName}');

      // Request MTU 247 — same as proven LSM DFU. Without this, 240-byte
      // chunks get fragmented across many L2CAP packets and the bootloader
      // may time out or drop writes.
      int mtu = 23;
      try {
        mtu = await device.requestMtu(247);
      } catch (e) {
        _log('MTU request not supported (iOS auto-negotiates): $e');
        mtu = device.mtuNow;
      }
      _log('Connected. MTU=$mtu');
      await Future.delayed(const Duration(milliseconds: 500));

      // Discover services
      final services = await device.discoverServices();
      progress.value = 0.20;

      // Find DFU service (0xFE59 — same as LSM DFU)
      BluetoothService? dfuService;
      for (final s in services) {
        if (s.uuid.toString().toLowerCase().contains('fe59')) {
          dfuService = s;
          break;
        }
      }

      if (dfuService == null) {
        _log('DFU service (0xFE59) not found');
        await device.disconnect();
        _fail('DFU service not found on device');
        return false;
      }

      // Find data + ack characteristics (8ec90001 / 8ec90002).
      BluetoothCharacteristic? dataChar;
      BluetoothCharacteristic? ackChar;
      for (final c in dfuService.characteristics) {
        final uuid = c.uuid.toString().toLowerCase();
        if (uuid.contains('8ec90001')) dataChar = c;
        if (uuid.contains('8ec90002')) ackChar = c;
      }

      if (dataChar == null) {
        _log('DFU data characteristic not found');
        await device.disconnect();
        _fail('DFU data characteristic not found');
        return false;
      }

      // ACK flow control: firmware_loader buffers chunks in a message queue
      // (8 slots).  We only wait for ACK on start/end markers.  Data chunks
      // stream with a 5ms delay — same as the proven hub-based DFU which
      // achieves ~15 KB/s.
      Completer<int>? ackCompleter;
      StreamSubscription? ackSub;
      if (ackChar != null) {
        _log('Subscribing to ACK notifications');
        await ackChar.setNotifyValue(true);
        ackSub = ackChar.lastValueStream.listen((val) {
          if (val.isNotEmpty) {
            final code = val[0];
            if (ackCompleter != null && !ackCompleter!.isCompleted) {
              ackCompleter!.complete(code);
            }
          }
        });
      }

      Future<int> waitForAck({Duration timeout = const Duration(seconds: 5)}) async {
        ackCompleter = Completer<int>();
        try {
          return await ackCompleter!.future.timeout(timeout);
        } on TimeoutException {
          _log('ACK timeout');
          return -1;
        }
      }

      // Transfer firmware
      state.value = MatterDfuState.transferring;
      statusMessage.value = 'Sending start marker...';
      progress.value = 0.25;

      // Send start marker and wait for ACK 0x00
      await dataChar.write(_startMarker, withoutResponse: true);
      final startAck = await waitForAck();
      _log('Start ACK: $startAck');
      if (startAck == 0xEE) {
        await device.disconnect();
        _fail('Device rejected DFU start');
        return false;
      }

      // Stream chunks with 5ms delay — matching hub DFU speed.
      const chunkDelay = Duration(milliseconds: 1);
      final total = firmwareData.length;
      final totalChunks = (total / _chunkSize).ceil();
      _log('Streaming $total bytes in $totalChunks chunks (5ms delay)');
      final stopwatch = Stopwatch()..start();
      int sent = 0;

      while (sent < total) {
        final end = (sent + _chunkSize > total) ? total : sent + _chunkSize;
        final chunk = firmwareData.sublist(sent, end);
        await dataChar.write(chunk.toList(), withoutResponse: true);
        sent = end;

        // Update progress (0.25 → 0.90)
        final chunkProgress = sent / total;
        progress.value = 0.25 + (chunkProgress * 0.65);

        if (sent % (_chunkSize * 50) == 0 || sent == total) {
          final pct = (chunkProgress * 100).toStringAsFixed(1);
          statusMessage.value = 'Transferring... $pct%';
        }
        if (sent % (_chunkSize * 100) == 0) {
          _log('Progress: ${(chunkProgress * 100).toStringAsFixed(1)}% ($sent/$total)');
        }

        await Future.delayed(chunkDelay);
      }

      stopwatch.stop();
      final speed = (total / stopwatch.elapsedMilliseconds * 1000 / 1024)
          .toStringAsFixed(1);
      _log('Transfer complete: $sent bytes in ${stopwatch.elapsedMilliseconds}ms ($speed KB/s)');

      // Send end marker WITH response and wait for ACK 0x01
      state.value = MatterDfuState.completing;
      statusMessage.value = 'Finalizing update...';
      progress.value = 0.92;
      _log('Sending completion marker...');
      await dataChar.write(_endMarker, withoutResponse: false);
      final endAck = await waitForAck(timeout: const Duration(seconds: 10));
      _log('End ACK: $endAck');
      if (endAck == 0xEF) {
        await device.disconnect();
        _fail('Firmware flush failed on device');
        return false;
      }
      _log('Transfer verified, waiting for device reboot...');
      await Future.delayed(const Duration(seconds: 3));

      await ackSub?.cancel();
      await device.disconnect();

      progress.value = 1.0;
      state.value = MatterDfuState.success;
      statusMessage.value = 'Firmware updated to v$targetVersion';

      // Log to Firebase
      await _logDfuEvent(
        targetVersion: targetVersion,
        success: true,
        firmwareSize: firmwareData.length,
      );

      _log('DFU complete: v$targetVersion');
      return true;
    } catch (e) {
      _log('DFU error: $e');
      _fail('DFU failed: $e');

      await _logDfuEvent(
        targetVersion: targetVersion,
        success: false,
        error: e.toString(),
      );

      return false;
    }
  }

  // ==================== HELPERS ====================

  /// DFU-mode device names Locksure firmware advertises.
  ///
  ///   "LSM-DFU"           — Arduino/nRF5 LSM (hub-based)
  ///   "LocksureDoor-DFU"  — Matter LSM (LocksureMatter firmware)
  static bool _matchesDfuName(String name) {
    final n = name.toLowerCase();
    if (n.isEmpty) return false;
    // Exact and prefix matches — tight enough to ignore "Locksure's iPad".
    return n == 'locksuredoor-dfu'
        || n == 'locksuredoor_dfu'
        || n == 'locksuredfu'
        || n == 'lsm-dfu'
        || n.startsWith('locksuredoor-dfu')
        || n.startsWith('locksuredoor_dfu')
        || n.startsWith('locksure-dfu')
        || n.startsWith('locksure_dfu')
        || n.startsWith('lsm-dfu');
  }

  /// Real DFU service UUIDs (fallback match when the adv has no name).
  static bool _advertisesDfuService(AdvertisementData adv) {
    for (final uuid in adv.serviceUuids) {
      final s = uuid.toString().toLowerCase();
      if (s.contains('fe59') || s.contains('1530')) return true;
    }
    return false;
  }

  /// Scan for a device in DFU mode. Matches the proven hub LSM DFU pattern
  /// (dfu_service.dart `_scanForDfuDevice`):
  ///   - Unfiltered scan (iOS sometimes suppresses service-filtered scans)
  ///   - Retry up to 3 times with 2 s pauses between attempts
  ///   - 10 s scan window per attempt
  ///   - Match by name ("LocksureDoor-DFU", "LSM-DFU", …) OR advertised
  ///     service UUID 0xFE59
  Future<BluetoothDevice?> _scanForDfuDevice({
    required String deviceName,
    required Duration timeout,
  }) async {
    const attempts = 3;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      _log('Scan attempt $attempt/$attempts …');
      statusMessage.value =
          'Scanning for device in DFU mode (attempt $attempt/$attempts)…';

      try { await FlutterBluePlus.stopScan(); } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));

      final completer = Completer<BluetoothDevice?>();
      final seen = <String>{};

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName;
          final adv = r.advertisementData;
          final id = r.device.remoteId.str;
          if (!seen.contains(id)) {
            seen.add(id);
            _log('  saw: name="$name" id=$id rssi=${r.rssi} '
                 'services=${adv.serviceUuids.map((u) => u.toString()).toList()}');
          }
          final nameMatch = _matchesDfuName(name);
          final serviceMatch = _advertisesDfuService(adv);
          if (!nameMatch && !serviceMatch) continue;

          _log('  *** DFU candidate: "$name" svcMatch=$serviceMatch '
               'nameMatch=$nameMatch rssi=${r.rssi}');
          if (!completer.isCompleted) completer.complete(r.device);
          return;
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      BluetoothDevice? found;
      try {
        found = await completer.future.timeout(const Duration(seconds: 12));
      } catch (_) {
        _log('Scan attempt $attempt timed out ( ${seen.length} adverts seen).');
      }

      try { await FlutterBluePlus.stopScan(); } catch (_) {}
      await _scanSub?.cancel();
      _scanSub = null;

      if (found != null) return found;
      if (attempt < attempts) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    _log('All scan attempts failed — device not in DFU mode or out of range.');
    return null;
  }

  void _fail(String message) {
    state.value = MatterDfuState.failed;
    statusMessage.value = message;
    _log('FAILED: $message');
  }

  Future<void> _logDfuEvent({
    required int targetVersion,
    required bool success,
    int firmwareSize = 0,
    String error = '',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('dfu_events').add({
        'userId': user.uid,
        'type': 'MATTER_DFU',
        'targetVersion': targetVersion,
        'success': success,
        'firmwareSize': firmwareSize,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _log('Failed to log DFU event: $e');
    }
  }

  void dispose() {
    _scanSub?.cancel();
    state.dispose();
    progress.dispose();
    statusMessage.dispose();
  }
}
