import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lockstate/authentication/index.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/model/account.dart';
import 'package:lockstate/model/room.dart';
import 'package:lockstate/screens/add_hub_screen.dart';
import 'package:lockstate/screens/add_matter_device_screen.dart';
import 'package:lockstate/screens/notifications_screen.dart';
import 'package:lockstate/services/pairing_analytics_service.dart';
import 'package:lockstate/screens/settings_screen.dart';
import 'package:lockstate/screens/chat_screen.dart';
import 'package:lockstate/services/ble_command_service.dart';
import 'package:lockstate/services/matter_home_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lockstate/screens/share_doors_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:lockstate/utils/battery_utils.dart';
import 'package:lockstate/services/dfu_service.dart';
import 'package:lockstate/services/matter_dfu_service.dart';
import 'package:lockstate/services/matter_ble_config_service.dart';
import 'package:momentum/momentum.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;
import 'package:lockstate/widgets/share_request_status.dart';
import 'package:lockstate/widgets/share_request_handler.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// var globals.lightSetting = 3; // Added by Jas to allow for different colour schemes need to move to globals

/// Convert a DateTime to a human-readable relative time string
String getRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'just now';
  } else if (difference.inMinutes < 60) {
    final mins = difference.inMinutes;
    return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
  } else if (difference.inHours < 24) {
    final hours = difference.inHours;
    final mins = difference.inMinutes % 60;
    if (mins == 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else {
      return '$hours ${hours == 1 ? 'hour' : 'hours'} $mins ${mins == 1 ? 'min' : 'mins'} ago';
    }
  } else if (difference.inDays < 7) {
    final days = difference.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  } else {
    // For older dates, show the date
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

/// Get the theme-aware color for a room state (matches lock icon color)
int roomStateColor(int state) {
  if (state == 0) return ColorUtils.colorGrey;
  if (state == 3) return ColorUtils.colorRed;
  // State 4 (closed) same as unlocked
  final s = (state == 4) ? 2 : state;
  switch (globals.lightSetting) {
    case 1: return s == 1 ? ColorUtils.colorGreen : ColorUtils.colorRed;
    case 2: return s == 1 ? ColorUtils.colorBlue : ColorUtils.colorAmber;
    case 3: return s == 1 ? ColorUtils.colorCyan : ColorUtils.colorAmber;
    default: return s == 1 ? ColorUtils.colorGreen : ColorUtils.colorRed;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

Color _lightSettingColour = Colors.red;

class _HomeScreenState extends State<HomeScreen> {
  late TextEditingController controller;
  String name = '';

  // void getLightSettingsFromFirestore() async {
  //   String newRoomName = "TEST ROOM";
  //   print('Getting LIGHT Settings from Firestore');

  //   void _shareRoom() {
  //     // Logic to obtain the roomId
  //     final roomId =
  //         'yourRoomId'; // Replace with actual logic to get the roomId

  //     // Navigate to ShareRoomPage
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => ShareRoomPage(roomId: roomId),
  //       ),
  //     );
  //   }

  //   final db = FirebaseFirestore.instance;
  //   var result = await db
  //       .collection('users')
  //       .doc(FirebaseAuth.instance.currentUser!.uid.toString())
  //       .collection('devices')
  //       .get();
  //   result.docs.forEach((res) {
  //     print(res.id);

  //     FirebaseFirestore.instance
  //         .collection('devices')
  //         .doc(res.id.toString())
  //         .get()
  //         .then((value) {
  //       if (!globals.gotLightSettings) {
  //         // print('LIGHTSETTING:');
  //         // print(value.get('lightSetting'));
  //         // sentLightSetting = value.get('lightSetting');
  //         globals.lightSetting = value.get('lightSetting').toInt();

  //         setState(() {
  //           globals.lightSetting = value.get('lightSetting').toInt();

  //           if (globals.lightSetting == 1) {
  //             _lightSettingColour = Colors.green;
  //           } else if (globals.lightSetting == 2) {
  //             _lightSettingColour = Colors.blue;
  //           } else if (globals.lightSetting == 3) {
  //             _lightSettingColour = Colors.cyan;
  //           }
  //         });
  //       }
  //       globals.gotLightSettings = true;
  //     });
  //   });
  // }

  late Account? currentAccount;
  late PageController pageController;
  int currentIndex = 0;

  // Onboarding overlay state
  bool _showOnboardingOverlay = false;
  bool _onboardingDismissed = false; // Track if user has dismissed the overlay

  // Cached latest LSM firmware version (fetched once at init for update badges)
  int _latestLsmFwVersion = 0;

  // Matter firmware + DFU state (fetched once at init; per-device DFU uses the
  // single shared MatterDfuService instance so its ValueNotifiers can drive UI).
  MatterFirmwareInfo? _matterFwInfo;
  final MatterDfuService _matterDfuService = MatterDfuService();
  bool _matterDfuInProgress = false;

  @override
  void initState() {
    pageController = PageController();
    controller = TextEditingController();
    super.initState();
    listenForShareRequests();
    listenForRequestResponses();
    initializeDisplayOrder();
    loadUserSettings();
    _fetchLatestLsmVersion();
    _fetchLatestMatterVersion();
  }

  Future<void> _fetchLatestMatterVersion() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();
      if (userDoc.exists) {
        _matterDfuService.testMode = userDoc.data()?['dfuTestMode'] ?? false;
      }
      print('[MATTER-DFU] Fetching latest firmware info (testMode=${_matterDfuService.testMode}, url=${_matterDfuService.firmwareJsonUrl})');
      final info = await _matterDfuService.fetchLatestFirmwareInfo();
      if (info != null) {
        print('[MATTER-DFU] Latest Matter firmware: v${info.version}, ${info.size} bytes');
        if (mounted) setState(() => _matterFwInfo = info);
      } else {
        print('[MATTER-DFU] fetchLatestFirmwareInfo returned null — JSON URL may not exist yet');
      }
    } catch (e) {
      print('[MATTER-DFU] Error fetching latest firmware: $e');
    }
  }

  /// Parse a firmware version string into an integer for comparison.
  /// Accepts "35", "v35", "1.0.35" (last segment) — anything else returns null.
  int? _parseMatterFwVersion(String v) {
    if (v.isEmpty) return null;
    final direct = int.tryParse(v);
    if (direct != null) return direct;
    // Strip non-numeric prefix and try last dotted segment.
    final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    final segments = cleaned.split('.').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    return int.tryParse(segments.last);
  }

  Future<void> _fetchLatestLsmVersion() async {
    try {
      // Set BLE target Hub ID from first device doc
      final devSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('devices')
          .limit(5)
          .get();
      for (var doc in devSnap.docs) {
        if (doc.id.startsWith('matter_')) continue; // Skip Matter devices for Hub ID extraction
        if (doc.id.length >= 16 && !doc.id.endsWith('99999')) {
          BleCommandService.targetHubId = BleCommandService.hubIdFromDeviceDocId(doc.id);
          print('[BLE] Global target Hub ID: ${BleCommandService.targetHubId}');
          break;
        }
      }

      final dfuService = DfuService();
      // Check test mode
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();
      if (userDoc.exists) {
        dfuService.testMode = userDoc.data()?['dfuTestMode'] ?? false;
      }
      final info = await dfuService.fetchLatestFirmwareInfo();
      if (info != null && mounted) {
        setState(() => _latestLsmFwVersion = info.version);
      }
    } catch (e) {
      print('[DFU] Error fetching latest firmware version: $e');
    }
  }

  /// Open a bottom sheet with options for a specific Matter device:
  /// firmware version + update button, and power-level radio buttons.
  /// No System OFF / auto-mode toggles for Matter devices.
  void _openMatterDeviceOptions(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final matterUniqueId = data['matterUniqueId'] as String?
        ?? doc.id.replaceFirst('matter_', '');
    final deviceName = (data['deviceName'] as String?)?.trim().isNotEmpty == true
        ? data['deviceName'] as String
        : matterUniqueId.substring(0, 8);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Wrap in ValueListenableBuilder so the sheet rebuilds when DFU
          // state changes (setState on the parent doesn't reach the sheet).
          return ValueListenableBuilder<MatterDfuState>(
            valueListenable: _matterDfuService.state,
            builder: (ctx, dfuStateVal, __) {
              final isDfuActive = dfuStateVal != MatterDfuState.idle;
              return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('devices')
                .doc(doc.id)
                .snapshots(),
            builder: (_, snap) {
              final liveData = (snap.data?.data() as Map<String, dynamic>?) ?? data;
              final currentFw = liveData['firmwareVersion'] as String? ?? '';
              final currentFwInt = _parseMatterFwVersion(currentFw);
              final latestVersion = _matterFwInfo?.version;
              // Show Update if we have latest and current is older, OR if we
              // have latest but can't parse current (user can still try).
              final updateAvailable = latestVersion != null
                  && (currentFwInt == null || latestVersion > currentFwInt);
              final powerLevel = (liveData['powerLevel'] as num?)?.toInt() ?? 3;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              deviceName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),

                    // Firmware section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.memory, color: Colors.white54, size: 18),
                          const SizedBox(width: 8),
                          const Text('Firmware',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              )),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentFw.isEmpty
                                      ? 'Current: —'
                                      : 'Current: v$currentFw',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                Text(
                                  latestVersion == null
                                      ? 'Latest: checking…'
                                      : 'Latest: v$latestVersion',
                                  style: TextStyle(
                                    color: updateAvailable ? Colors.orange : Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isDfuActive)
                            const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (_matterFwInfo == null)
                            TextButton(
                              onPressed: () async {
                                await _fetchLatestMatterVersion();
                                setModalState(() {});
                              },
                              child: const Text('Check'),
                            )
                          else if (updateAvailable)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _runMatterDfu(
                                matterUniqueId: matterUniqueId,
                                deviceDocId: doc.id,
                                sheetContext: ctx,
                              ),
                              child: const Text('Update'),
                            )
                          else
                            const Text('Up to date',
                                style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                        ],
                      ),
                    ),

                    // DFU in progress — replace firmware + power sections
                    // with full-screen progress (matches hub-based DFU style)
                    if (isDfuActive) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ValueListenableBuilder<MatterDfuState>(
                              valueListenable: _matterDfuService.state,
                              builder: (_, dfuState, __) {
                                IconData icon;
                                Color color;
                                switch (dfuState) {
                                  case MatterDfuState.downloadingFirmware:
                                  case MatterDfuState.fetchingMetadata:
                                    icon = Icons.cloud_download;
                                    color = Colors.orange;
                                    break;
                                  case MatterDfuState.scanningForDevice:
                                    icon = Icons.bluetooth_searching;
                                    color = Colors.blue;
                                    break;
                                  case MatterDfuState.connectingToDevice:
                                    icon = Icons.bluetooth_connected;
                                    color = Colors.blue;
                                    break;
                                  case MatterDfuState.transferring:
                                    icon = Icons.upload;
                                    color = Colors.orange;
                                    break;
                                  case MatterDfuState.completing:
                                    icon = Icons.pending;
                                    color = Colors.orange;
                                    break;
                                  case MatterDfuState.success:
                                    icon = Icons.check_circle;
                                    color = Colors.green;
                                    break;
                                  case MatterDfuState.failed:
                                    icon = Icons.error;
                                    color = Colors.red;
                                    break;
                                  default:
                                    icon = Icons.system_update;
                                    color = Colors.orange;
                                }
                                return Icon(icon, size: 48, color: color);
                              },
                            ),
                            const SizedBox(height: 20),
                            ValueListenableBuilder<String>(
                              valueListenable: _matterDfuService.statusMessage,
                              builder: (_, msg, __) => Text(
                                msg,
                                style: const TextStyle(fontSize: 15, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ValueListenableBuilder<double>(
                              valueListenable: _matterDfuService.progress,
                              builder: (_, prog, __) => Column(
                                children: [
                                  SizedBox(
                                    height: 12,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: prog,
                                        backgroundColor: Colors.white24,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(prog * 100).toInt()}%',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Do not close the app or move away from the device.',
                              style: TextStyle(fontSize: 12, color: Colors.white38, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (!isDfuActive) ...[
                    const Divider(color: Colors.white24, height: 1),

                    // Power level section
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_tethering, color: Colors.white54, size: 18),
                          SizedBox(width: 8),
                          Text('Power Level',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              )),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Requires device to be in BLE range',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                    ...List.generate(5, (i) {
                      final level = i + 1;
                      final label = const [
                        'Low', 'Medium-Low', 'Medium', 'High', 'Maximum'
                      ][i];
                      return RadioListTile<int>(
                        dense: true,
                        value: level,
                        groupValue: powerLevel,
                        activeColor: Colors.blue,
                        title: Text(label, style: const TextStyle(color: Colors.white)),
                        onChanged: isDfuActive
                            ? null
                            : (v) {
                                if (v == null) return;
                                setModalState(() {});
                                _setMatterPowerLevel(
                                  deviceDocId: doc.id,
                                  level: v,
                                );
                              },
                      );
                    }),
                    const SizedBox(height: 16),
                    ], // !isDfuActive
                  ],
                ),
              );
            },
          );
            },
          );
        },
      ),
    );
  }

  /// Trigger DFU on a specific Matter device.
  /// 1. Calls triggerDfuMode(uniqueId) — pushes device into BLE-DFU advertising.
  /// 2. Runs MatterDfuService.performDfu — scans, connects, transfers firmware.
  /// 3. Updates Firestore with new firmware version on success.
  Future<void> _runMatterDfu({
    required String matterUniqueId,
    required String deviceDocId,
    required BuildContext sheetContext,
  }) async {
    if (_matterDfuInProgress) return;
    final fwInfo = _matterFwInfo;
    if (fwInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firmware info not loaded yet — try again in a moment')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: sheetContext,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Update Firmware', style: TextStyle(color: Colors.white)),
        content: Text(
          'Download v${fwInfo.version} and flash this Matter device?\n\n'
          'The app will send a DFU command to the device. If the device '
          'doesn\'t respond, long-press the button to enter DFU mode manually.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _matterDfuInProgress = true);

    try {
      // 2. Download firmware binary (validates size + checksums).
      final fwData = await _matterDfuService.downloadFirmware(fwInfo);
      if (fwData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Firmware download failed')),
          );
        }
        return;
      }

      // 3. Perform the DFU transfer. Pass matterUniqueId so the service
      //    can try remote DFU trigger via HomeKit Identify before scanning.
      final ok = await _matterDfuService.performDfu(
        firmwareData: fwData,
        targetVersion: fwInfo.version,
        matterUniqueId: matterUniqueId,
      );

      if (ok) {
        // Do NOT write firmwareVersion optimistically — the device reports
        // its running version via Matter on reconnect.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Firmware updated to v${fwInfo.version}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Firmware update failed')),
          );
        }
      }
    } catch (e) {
      print('[MATTER-DFU] runMatterDfu error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firmware update error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _matterDfuInProgress = false);
    }
  }

  /// Send power-level command to a Matter device over BLE NUS and write the
  /// value to Firestore. Requires the device to be in BLE range.
  Future<void> _setMatterPowerLevel({
    required String deviceDocId,
    required int level,
  }) async {
    final ble = MatterBleConfigService();
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setting power level to $level…'), duration: const Duration(seconds: 2)),
      );
      final connected = await ble.scanAndConnect();
      if (!connected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not connect to device — is it in range?')),
          );
        }
        return;
      }
      final ok = await ble.setPowerLevel(level);
      await ble.disconnect();
      if (ok) {
        await FirebaseFirestore.instance.collection('devices').doc(deviceDocId).update({
          'powerLevel': level,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Power level set to $level')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to set power level')),
        );
      }
    } catch (e) {
      print('[MATTER-BLE] setPowerLevel error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Fetch battery percentages for all LSMs on a door
  /// Hub devices: reads volts/batVolts from notifications collection
  /// Matter devices: reads batteryPercent from device doc or notifications
  Future<List<int>> _getDeviceBatteries(String roomId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final devSnap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('devices')
          .where('roomId', isEqualTo: roomId)
          .get();
      List<int> results = [];
      for (var userDoc in devSnap.docs) {
        final id = userDoc.id;
        if (id.endsWith('99999')) continue;
        if (!id.startsWith('matter_') && id.length < 16) continue;

        // Matter devices: read batteryPercent from device doc directly
        if (id.startsWith('matter_')) {
          final deviceDoc = await FirebaseFirestore.instance
              .collection('devices').doc(id).get();
          if (deviceDoc.exists) {
            final bat = deviceDoc.data()?['batteryPercent'] as int? ?? 0;
            if (bat > 0) {
              results.add(bat);
              continue;
            }
          }
          // Fallback: check notifications for batteryPercent
          final notifSnap = await FirebaseFirestore.instance
              .collection('notifications')
              .where('deviceId', isEqualTo: id)
              .get();
          if (notifSnap.docs.isNotEmpty) {
            final sorted = notifSnap.docs
              ..sort((a, b) => (b.data()['received_at'] ?? '').compareTo(a.data()['received_at'] ?? ''));
            final bat = sorted.first.data()['batteryPercent'] as int? ?? 0;
            if (bat > 0) {
              results.add(bat);
              continue;
            }
          }
          results.add(0);
          continue;
        }

        // Hub devices: read volts/batVolts from notifications
        final notifSnap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('deviceId', isEqualTo: id)
            .get();
        if (notifSnap.docs.isNotEmpty) {
          final sorted = notifSnap.docs
            ..sort((a, b) => (b.data()['received_at'] ?? '').compareTo(a.data()['received_at'] ?? ''));
          final data = sorted.first.data();
          // Try top-level volts first (Hub patches this)
          final topVolts = data['volts'] as int? ?? 0;
          if (topVolts > 0) {
            results.add(BatteryUtils.calculateBatteryPercentage(topVolts));
            continue;
          }
          // Fallback: nested path message.uplink_message.decoded_payload.batVolts
          final msg = data['message'] as Map<String, dynamic>?;
          final uplink = msg?['uplink_message'] as Map<String, dynamic>?;
          final payload = uplink?['decoded_payload'] as Map<String, dynamic>?;
          final batVolts = payload?['batVolts'] as int? ?? 0;
          if (batVolts > 0) {
            results.add(BatteryUtils.calculateBatteryPercentage(batVolts));
            continue;
          }
        }
        results.add(0);
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  /// Build a compact battery column widget (percentage + horizontal battery bar)
  Widget _batteryColumn(int pct, {bool compact = false}) {
    final Color bgColor = pct >= 60 ? Colors.green : pct >= 20 ? Colors.orange : Colors.red;
    final fontSize = compact ? 15.0 : 16.0;
    final barHeight = compact ? 13.0 : 14.0;
    final gap = compact ? 2.0 : 3.0;
    // Proportional width: 2:1 aspect ratio
    final barWidth = barHeight * 2.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$pct%',
          style: TextStyle(color: bgColor, fontSize: fontSize, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: gap),
        // Battery icon with fixed proportions (2:1 aspect ratio)
        SizedBox(
          width: barWidth + 3, // +3 for nub
          height: barHeight,
          child: Row(
            children: [
              SizedBox(
                width: barWidth,
                height: barHeight,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade600, width: 1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: pct / 100,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
              // Battery nub
              Container(
                width: 3,
                height: barHeight * 0.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(1)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Load user settings from Firestore
  Future<void> loadUserSettings() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          // Always on — toggles removed from settings
          globals.showBatteryPercentage = true;
          globals.showSignalStrength = true;
        });
      }
    } catch (e) {
      print('Error loading user settings: $e');
    }
  }

  // Initialize displayOrder for existing rooms that don't have it
  Future<void> initializeDisplayOrder() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get all rooms for the current user
      final roomsSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      // Only update rooms that don't have displayOrder
      final batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;

      for (int i = 0; i < roomsSnapshot.docs.length; i++) {
        final doc = roomsSnapshot.docs[i];
        if (!doc.data().containsKey('displayOrder')) {
          batch.update(doc.reference, {'displayOrder': i});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
        print('Initialized displayOrder for rooms that were missing it');
      }
    } catch (e) {
      print('Error initializing displayOrder: $e');
    }
  }

  buildBottomNavigationBar() {
    return BottomNavigationBar(
        selectedItemColor: _lightSettingColour,
        currentIndex: currentIndex,
        unselectedItemColor: Colors.white,
        onTap: (int index) {
          setState(() {
            currentIndex = index;
          });
          pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 100),
            curve: Curves.bounceIn,
          );
        },
        items: const [
          BottomNavigationBarItem(
            // backgroundColor: Color(ColorUtils.color1),

            icon: Icon(
              Icons.home,
              // color: Colors.grey,
              size: 30,
            ),

            label: 'Home',
          ),
          BottomNavigationBarItem(
            // backgroundColor: Color(ColorUtils.color1),
            icon: Icon(
              Icons.history,
              // color: Colors.grey,
              size: 30,
            ),
            label: 'History',
          ),
          BottomNavigationBarItem(
            // backgroundColor: Color(ColorUtils.color1),
            icon: Icon(
              Icons.settings,
              // color: Colors.grey,
              size: 30,
            ),
            label: 'Settings',
          ),
        ],
        backgroundColor: const Color.fromARGB(255, 0, 0, 0));
  }

  // Function to delete a room and its associated devices
  /// Cached data for undo — stored between delete and undo timeout
  Map<String, dynamic>? _deletedRoomData;
  List<Map<String, dynamic>>? _deletedDevicesData;
  List<int>? _deletedUnitIds;

  Future<void> deleteRoom(String roomId, String userId) async {
    final db = FirebaseFirestore.instance;

    try {
      // Cache room data for undo
      final roomDoc = await db.collection('rooms').doc(roomId).get();
      _deletedRoomData = roomDoc.exists ? {'id': roomId, ...roomDoc.data()!} : null;

      // Get all devices for this room
      var userDevices = await db
          .collection('users')
          .doc(userId)
          .collection('devices')
          .where('roomId', isEqualTo: roomId)
          .get();

      // Set BLE target Hub ID from device doc
      if (userDevices.docs.isNotEmpty) {
        BleCommandService.targetHubId = BleCommandService.hubIdFromDeviceDocId(userDevices.docs.first.id);
      }

      // Cache device data for undo + extract unit IDs
      _deletedDevicesData = [];
      _deletedUnitIds = [];
      final List<String> matterUniqueIdsToUnpair = [];
      for (var deviceDoc in userDevices.docs) {
        final mainDoc = await db.collection('devices').doc(deviceDoc.id).get();
        final mergedData = mainDoc.exists ? mainDoc.data()! : deviceDoc.data();
        _deletedDevicesData!.add({
          'id': deviceDoc.id,
          'userData': deviceDoc.data(),
          'mainData': mergedData,
        });

        // Matter device? Queue it for un-pairing from Apple Home
        if (mergedData['connectionType'] == 'MATTER') {
          final matterId = mergedData['matterUniqueId'] as String?;
          if (matterId != null && matterId.isNotEmpty) {
            matterUniqueIdsToUnpair.add(matterId);
          }
        } else {
          // Hub device — track unit ID for BLE delete
          final id = deviceDoc.id;
          if (id.length >= 6) {
            final unitId = int.tryParse(id.substring(id.length - 6));
            if (unitId != null && unitId > 0) _deletedUnitIds!.add(unitId);
          }
        }
      }

      // Signal Hub to remove door from knownIDs via BLE
      // Only send ONE delete — Hub removes the whole door pair (indoor+outdoor)
      if (_deletedUnitIds!.isNotEmpty) {
        await BleCommandService.sendCommand('dd', _deletedUnitIds!.first.toString());
        print('[DELETE] BLE delete sent for unitID: ${_deletedUnitIds!.first}');
      }

      // Unpair Matter accessories from Apple Home
      if (matterUniqueIdsToUnpair.isNotEmpty) {
        final matterHome = MatterHomeService();
        for (final matterId in matterUniqueIdsToUnpair) {
          try {
            await matterHome.unsubscribeFromDevice(matterId);
            final ok = await matterHome.removeAccessory(matterId);
            print('[DELETE] Matter accessory unpair $matterId: ${ok ? "ok" : "failed"}');
          } catch (e) {
            print('[DELETE] Matter accessory unpair error for $matterId: $e');
          }
        }
      }

      // Delete from Firebase
      var batch = db.batch();
      for (var deviceDoc in userDevices.docs) {
        batch.delete(deviceDoc.reference);
        batch.delete(db.collection('devices').doc(deviceDoc.id));
        final notifs = await db.collection('notifications')
            .where('deviceId', isEqualTo: deviceDoc.id).get();
        for (var notif in notifs.docs) batch.delete(notif.reference);
        final history = await db.collection('devices')
            .doc(deviceDoc.id).collection('history').get();
        for (var hist in history.docs) batch.delete(hist.reference);
      }
      batch.delete(db.collection('rooms').doc(roomId));
      await batch.commit();
      print('[DELETE] Room, devices, notifications and history deleted');
    } catch (e) {
      print('Error deleting room: $e');
      rethrow;
    }
  }

  Future<void> undoDeleteRoom() async {
    if (_deletedRoomData == null || _deletedDevicesData == null) return;
    final db = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      // Restore room
      final roomId = _deletedRoomData!['id'] as String;
      final roomData = Map<String, dynamic>.from(_deletedRoomData!);
      roomData.remove('id');
      await db.collection('rooms').doc(roomId).set(roomData);

      // Restore devices
      for (var dev in _deletedDevicesData!) {
        final devId = dev['id'] as String;
        final mainData = dev['mainData'] as Map<String, dynamic>;
        final userData = dev['userData'] as Map<String, dynamic>;
        await db.collection('devices').doc(devId).set(mainData);
        await db.collection('users').doc(userId).collection('devices').doc(devId).set(userData);
      }

      // Restore doors on Hub via BLE — restores exact pre-delete knownID layout
      await BleCommandService.sendCommand('ud', '1');
      print('[UNDO] BLE undoDelete sent');

      print('[UNDO] Room $roomId and ${_deletedDevicesData!.length} devices restored');
    } catch (e) {
      print('[UNDO] Error: $e');
    } finally {
      _deletedRoomData = null;
      _deletedDevicesData = null;
      _deletedUnitIds = null;
    }
  }

  /// Show door detail popup with individual device information
  void showDoorDetailPopup(Room room) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.door_front_door, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      room.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      room.state == 1 ? 'Locked' : (room.state == 2 || room.state == 4) ? 'Unlocked' : room.state == 3 ? 'Open' : 'Not Set',
                      style: TextStyle(
                        color: room.state == 1 ? Colors.greenAccent : room.state == 0 ? Colors.grey : Colors.orangeAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey, height: 1),
              // Device list
              Flexible(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('devices')
                      .where('roomId', isEqualTo: room.roomId)
                      .where('userId', isEqualTo: userId)
                      .snapshots(),
                  builder: (context, deviceSnapshot) {
                    if (deviceSnapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    if (!deviceSnapshot.hasData || deviceSnapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('No devices found', style: TextStyle(color: Colors.white54)),
                      );
                    }

                    // Filter: keep LSM and Matter devices
                    // Exclude: 99999 placeholders, Hub device (short ID)
                    final devices = deviceSnapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final id = data['deviceId'] as String? ?? doc.id;
                      if (id.endsWith('99999')) return false;
                      if (id.startsWith('matter_')) return true; // Always include Matter devices
                      if (id.length < 16) return false;
                      return true;
                    }).toList();

                    if (devices.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('No devices found', style: TextStyle(color: Colors.white54)),
                      );
                    }

                    // If only one real device, it's a Thumb Turn setup
                    final isThumbTurn = devices.length == 1;

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final deviceData = devices[index].data() as Map<String, dynamic>;
                        final deviceId = deviceData['deviceId'] as String? ?? devices[index].id;
                        final isIndoor = deviceData['isIndoor'] as bool? ?? true;

                        // Determine device type label
                        String deviceTypeLabel;
                        IconData deviceIcon;
                        if (isThumbTurn) {
                          deviceTypeLabel = 'Thumb Turn Monitor';
                          deviceIcon = Icons.radio_button_checked;
                        } else if (isIndoor) {
                          deviceTypeLabel = 'Key Turn Inside Monitor';
                          deviceIcon = Icons.home;
                        } else {
                          deviceTypeLabel = 'Key Turn Outside Monitor';
                          deviceIcon = Icons.lock_outline;
                        }

                        // Build device card with notification data
                        return _buildDeviceDetailCard(
                          deviceId: deviceId,
                          roomId: room.roomId,
                          deviceTypeLabel: deviceTypeLabel,
                          deviceIcon: deviceIcon,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build a single device detail card with data from latest notification
  Widget _buildDeviceDetailCard({
    required String deviceId,
    required String roomId,
    required String deviceTypeLabel,
    required IconData deviceIcon,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('received_at', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, notifSnapshot) {
        int? batteryPercent;
        String lastOpTime = '--';
        String lastOpState = '--';
        String temperature = '--';
        DateTime? lastOpDate;

        if (notifSnapshot.hasData && notifSnapshot.data!.docs.isNotEmpty) {
          final notif = notifSnapshot.data!.docs.first.data() as Map<String, dynamic>;
          final isMatter = deviceId.startsWith('matter_') ||
              notif['connectionType'] == 'MATTER';
          final msg = notif['message'] as Map<String, dynamic>?;
          final decoded = msg?['uplink_message']?['decoded_payload'] as Map<String, dynamic>?;

          if (decoded != null) {
            if (isMatter) {
              // Matter: battery from PowerSource cluster
              final matterBat = decoded['batteryPercent'] as int? ??
                  notif['batteryPercent'] as int?;
              if (matterBat != null && matterBat >= 0) {
                batteryPercent = matterBat;
              }
            } else {
              // Hub: battery from voltage (with moving average)
              final rawVolts = decoded['batVolts'] as int?;
              if (rawVolts != null && rawVolts > 0) {
                int avgRaw = BatteryUtils.addReading(deviceId, rawVolts);
                batteryPercent = BatteryUtils.calculateBatteryPercentage(avgRaw);
              }
            }

            // Lock state (same field for both)
            final lockState = decoded['lockState'] as int?;
            if (lockState != null) {
              lastOpState = lockState == 1 ? 'Locked' : lockState == 2 ? 'Unlocked' : 'Unknown';
            }

            // Temperature (Hub only — Matter doesn't send temperature here)
            if (!isMatter) {
              final temp = decoded['temperature'];
              if (temp != null) {
                temperature = '${temp}°C';
              }
            }
          }

          // Timestamp
          final isoString = msg?['received_at'] as String? ??
              notif['received_at'] as String?;
          if (isoString != null) {
            try {
              lastOpDate = DateTime.parse(isoString).toLocal();
              lastOpTime = '${lastOpDate.day}/${lastOpDate.month}/${lastOpDate.year} ${lastOpDate.hour}:${lastOpDate.minute.toString().padLeft(2, '0')}';
            } catch (_) {}
          }
        }

        final relativeTime = lastOpDate != null ? getRelativeTime(lastOpDate) : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device type header
              Row(
                children: [
                  Icon(deviceIcon, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    deviceTypeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Info rows
              Row(
                children: [
                  const Icon(Icons.battery_std, color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  const Text('Battery: ', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  batteryPercent != null
                      ? BatteryUtils.batteryWidget(batteryPercent, iconSize: 16, fontSize: 13)
                      : const Text('--', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              _buildInfoRow(
                Icons.access_time,
                'Last Operation',
                relativeTime.isNotEmpty ? '$relativeTime ($lastOpTime)' : lastOpTime,
              ),
              const SizedBox(height: 10),
              _buildInfoRow(
                Icons.lock,
                'Last State',
                lastOpState,
                valueColor: lastOpState == 'Locked' ? Colors.greenAccent : lastOpState == 'Unlocked' ? Colors.orangeAccent : Colors.white54,
              ),
              const SizedBox(height: 10),
              _buildInfoRow(
                Icons.thermostat,
                'Temperature',
                temperature,
              ),
              if (temperature != '--') ...[
                const SizedBox(height: 6),
                const Text(
                  'This is the temperature of the device when the last operation was sent and not the temperature right now',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Build a single info row for the device detail card
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Estimate CR2032 battery life based on power settings
  /// CR2032: ~230mAh, ~10 ops/day, TX ~25s per op
  /// Power levels: 1=0dBm(5mA TX), 4=6dBm(7mA TX), 5=8dBm(9mA TX)
  // Power level display name for auto mode
  String powerLevelName(int level) {
    switch (level) {
      case 1: return 'Low power (close range)';
      case 2: return 'Medium power';
      case 3: return 'Medium-high power';
      case 4: return 'High power (long range)';
      case 5: return 'Maximum power (extended range)';
      default: return 'Level $level';
    }
  }

  String estimateBatteryLife(bool systemOff, int powerLevel, int opsPerDay) {
    // PPK2-measured energy per event (µAh) — Fix D PHY+dBm ladder
    // System OFF measured 2026-04-16 (ppk-20260416T024259)
    // System ON  measured 2026-04-16 (ppk-20260416T032016)
    Map<int, double> sysOffUah = {1: 6.10, 2: 6.35, 3: 6.78, 4: 7.58, 5: 8.56};
    Map<int, double> sysOnUah  = {1: 4.96, 2: 5.21, 3: 5.62, 4: 6.18, 5: 8.56};

    double energyPerEvent = systemOff
        ? (sysOffUah[powerLevel] ?? 6.35)
        : (sysOnUah[powerLevel] ?? 5.21);

    // Sleep current: System OFF = 3µA, System ON = 13µA
    double sleepUa = systemOff ? 3.0 : 13.0;

    // 4 events per cycle (UNLOCK + OPEN + CLOSED + LOCK)
    int eventsPerDay = opsPerDay * 4;

    // Energy per day (µAh)
    double activeUahPerDay = energyPerEvent * eventsPerDay;
    double sleepUahPerDay = sleepUa * 24.0;
    double selfDischargeUahPerDay = (225000 * 0.03) / 365; // 3% self-discharge
    double totalUahPerDay = activeUahPerDay + sleepUahPerDay + selfDischargeUahPerDay;

    // CR2032 capacity 225 mAh = 225,000 µAh
    double days = 225000.0 / totalUahPerDay;
    if (days >= 730) return '~${(days / 365).floor()} years';
    if (days >= 365) {
      int months = ((days - 365) / 30.44).floor();
      return months > 0 ? '~1 year $months months' : '~1 year';
    }
    int m = (days / 30.44).floor();
    return '~$m months';
  }

  Future<void> showBatteryPowerDialog(Room room) async {
    int powerLevel1 = 4;    // Indoor
    int powerLevel2 = 4;    // Outdoor
    bool systemOff1 = false; // Indoor: High Performance ON
    bool systemOff2 = false; // Outdoor: High Performance ON
    bool autoMode1 = true;   // Indoor: Auto power management (default)
    bool autoMode2 = true;   // Outdoor: Auto power management (default)
    int opsPerDay = 10;
    bool hasMatterDevices = false;
    bool hasHubDevices = false;
    List<DocumentSnapshot> deviceDocs = [];
    Map<String, int> batteryPercent = {};
    String? indoorDocId;
    String? outdoorDocId;

    try {
      // Fetch associated devices
      final devicesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('devices')
          .where('roomId', isEqualTo: room.roomId)
          .get();

      // Filter: keep LSM and Matter devices
      // Exclude: 99999 placeholders, Hub device (hubId + "0" = 13 chars)
      deviceDocs = devicesSnapshot.docs.where((doc) {
        String deviceId = doc.id;
        if (deviceId.endsWith('99999')) return false;
        if (deviceId.startsWith('matter_')) return true; // Always include Matter devices
        if (deviceId.length < 16) return false; // Hub device is ~13 chars, LSMs are 18+
        return true;
      }).toList();


      print('Found ${deviceDocs.length} valid devices (excluding *99999)');

      // Set BLE target Hub ID from first device doc ID
      if (deviceDocs.isNotEmpty) {
        BleCommandService.targetHubId = BleCommandService.hubIdFromDeviceDocId(deviceDocs.first.id);
        print('[BLE] Target Hub ID: ${BleCommandService.targetHubId}');
      }

      // Fetch power levels and latest battery readings for each device
      for (var deviceDoc in deviceDocs) {
        // Fetch power level
        final device = await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceDoc.id)
            .get();

        if (device.exists) {
          final data = device.data()!;
          final isMatterDevice = deviceDoc.id.startsWith('matter_') ||
              data['connectionType'] == 'MATTER';
          if (isMatterDevice) { hasMatterDevices = true; } else { hasHubDevices = true; }
          bool isIndoor = data['isIndoor'] ?? true;

          if (!isMatterDevice) {
            // Hub device — read power settings
            if (isIndoor) {
              powerLevel1 = data['powerLevel'] ?? 4;
              systemOff1 = data['lsmSystemOff'] ?? true;
              autoMode1 = data['powerAutoMode'] ?? true;
              indoorDocId = deviceDoc.id;
            } else {
              powerLevel2 = data['powerLevel'] ?? 4;
              systemOff2 = data['lsmSystemOff'] ?? true;
              autoMode2 = data['powerAutoMode'] ?? true;
              outdoorDocId = deviceDoc.id;
            }
          }

          // Read battery — Matter uses batteryPercent, Hub uses volts
          if (isMatterDevice) {
            final matterBat = data['batteryPercent'] as int?;
            if (matterBat != null && matterBat >= 0) {
              batteryPercent[deviceDoc.id] = matterBat;
              print('Device ${deviceDoc.id}: Matter battery=$matterBat%');
            }
          } else {
            // Hub: read from device doc volts field
            final rawVolts = data['volts'] as int? ?? 0;
            if (rawVolts > 0) {
              batteryPercent[deviceDoc.id] = BatteryUtils.calculateBatteryPercentage(rawVolts);
              print('Device ${deviceDoc.id}: volts=$rawVolts pct=${batteryPercent[deviceDoc.id]}%');
            } else {
              // Fallback: read from notifications collection
              final notifSnap = await FirebaseFirestore.instance
                  .collection('notifications')
                  .where('deviceId', isEqualTo: deviceDoc.id)
                  .get();
              if (notifSnap.docs.isNotEmpty) {
                final sorted = notifSnap.docs
                  ..sort((a, b) => (b.data()['received_at'] ?? '').compareTo(a.data()['received_at'] ?? ''));
                final notifData = sorted.first.data();
                final nVolts = notifData['volts'] as int? ?? 0;
                if (nVolts > 0) {
                  batteryPercent[deviceDoc.id] = BatteryUtils.calculateBatteryPercentage(nVolts);
                } else {
                  final msg = notifData['message'] as Map<String, dynamic>?;
                  final uplink = msg?['uplink_message'] as Map<String, dynamic>?;
                  final payload = uplink?['decoded_payload'] as Map<String, dynamic>?;
                  final batVolts = payload?['batVolts'] as int? ?? 0;
                  if (batVolts > 0) {
                    batteryPercent[deviceDoc.id] = BatteryUtils.calculateBatteryPercentage(batVolts);
                  }
                }
              } else {
                print('Device ${deviceDoc.id}: no notifications');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching device data: $e');
    }

    // DFU state
    final dfuService = DfuService();
    bool dfuInProgress = false;
    int latestFwVersion = 0;
    Map<String, int> installedVersions = {};  // deviceDocId → firmware version

    // Check if DFU test mode is enabled for this user
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();
      if (userDoc.exists) {
        dfuService.testMode = userDoc.data()?['dfuTestMode'] ?? false;
        print('[DFU] dfuTestMode from Firebase: ${dfuService.testMode}');
      }
    } catch (e) {
      print('[DFU] Error reading dfuTestMode: $e');
    }

    // Fetch latest available firmware version from CDN
    try {
      final fwInfo = await dfuService.fetchLatestFirmwareInfo();
      if (fwInfo != null) latestFwVersion = fwInfo.version;
    } catch (e) {
      print('[DFU] Error fetching latest firmware info: $e');
    }

    // Fetch installed LSM versions from room doc's lsmVersions map
    try {
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(room.roomId)
          .get();
      if (roomDoc.exists) {
        final lsmVersions = roomDoc.data()?['lsmVersions'] as Map<String, dynamic>? ?? {};
        print('[DFU] lsmVersions from room: $lsmVersions');
        // Keys are "{hubId}_{unitId}", device doc IDs are "{hubId}{unitId}" (no underscore)
        // Match by checking if deviceDocId starts with hubId and ends with unitId
        for (var deviceDoc in deviceDocs) {
          final docId = deviceDoc.id;
          for (var entry in lsmVersions.entries) {
            // entry.key = "hubId_unitId", docId = "hubIdunitId"
            final keyNoUnderscore = entry.key.replaceAll('_', '');
            if (docId == keyNoUnderscore) {
              installedVersions[docId] = (entry.value is int) ? entry.value : int.tryParse(entry.value.toString()) ?? 0;
              print('[DFU] Device $docId: installed v${installedVersions[docId]}');
              break;
            }
          }
        }
      }
    } catch (e) {
      print('[DFU] Error fetching lsmVersions: $e');
    }

    final scrollController = ScrollController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Flash state for update buttons
        bool flashOn = true;
        Timer? flashTimer;

        return StatefulBuilder(builder: (context, setState) {
          // Auto-save settings to Firebase + BLE on any change
          bool settingsPendingConfirm = false;

          void saveSettings() async {
            try {
              if (indoorDocId != null) {
                await FirebaseFirestore.instance
                    .collection('devices').doc(indoorDocId)
                    .update({'powerLevel': powerLevel1, 'lsmSystemOff': systemOff1, 'powerAutoMode': autoMode1});
                BleCommandService.setLsmSystemOff(systemOff1);
                BleCommandService.setLsmPowerLevel(powerLevel1);
              }
              if (outdoorDocId != null) {
                await FirebaseFirestore.instance
                    .collection('devices').doc(outdoorDocId)
                    .update({'powerLevel': powerLevel2, 'lsmSystemOff': systemOff2, 'powerAutoMode': autoMode2});
                BleCommandService.setLsmSystemOff(systemOff2);
                BleCommandService.setLsmPowerLevel(powerLevel2);
              }
              if (!settingsPendingConfirm) {
                settingsPendingConfirm = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Setting saved. Turn the key — a magenta flash on the LSM confirms it was applied.'),
                    backgroundColor: Colors.blueGrey,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            } catch (e) {
              print('Error saving settings: $e');
            }
          }

          // Start flash timer once. Include Matter device(s) so the Matter
          // update badge flashes in unison with the hub LSM Update button.
          final matterLatest = _matterFwInfo?.version;
          final anyMatterOutOfDate = matterLatest != null
              && deviceDocs.where((d) => d.id.startsWith('matter_')).any((d) {
                final data = d.data() as Map<String, dynamic>;
                final cur = _parseMatterFwVersion(data['firmwareVersion'] as String? ?? '');
                return cur == null || cur < matterLatest;
              });
          bool hasAnyUpdate = (indoorDocId != null && latestFwVersion > 0 && (installedVersions[indoorDocId] ?? 0) < latestFwVersion) ||
                              (outdoorDocId != null && latestFwVersion > 0 && (installedVersions[outdoorDocId] ?? 0) < latestFwVersion) ||
                              anyMatterOutOfDate;
          if (hasAnyUpdate && flashTimer == null) {
            flashTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
              setState(() => flashOn = !flashOn);
            });
          }

          // DFU helper — runs update for one LSM
          Future<void> runDfu(String label) async {
            // Check battery level — require ≥50% for DFU
            final docId = label == 'Indoor' ? indoorDocId : outdoorDocId;
            final batPct = batteryPercent[docId] ?? 0;
            if (batPct > 0 && batPct < 30) {
              await showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Low Battery Warning'),
                  content: Text(
                    'The $label LSM battery is at $batPct%.\n\n'
                    'Firmware updates may fail with low battery. '
                    'Consider replacing the battery before updating.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
                  ],
                ),
              );
              return;
            }

            final confirm = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text('Update $label LSM?'),
                content: Text(
                  'Update the $label LSM firmware.\n\n'
                  '1. Turn the key when prompted\n'
                  '2. Stay near the door (~60s)\n'
                  '3. Do not close the app'
                  '${batPct > 0 ? '\n\nBattery: $batPct%' : ''}',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, true),
                    child: const Text('Update', style: TextStyle(color: Colors.orange))),
                ],
              ),
            );
            if (confirm != true) return;

            setState(() => dfuInProgress = true);
            final latest = await dfuService.fetchLatestFirmwareInfo();
            if (latest == null) { setState(() => dfuInProgress = false); return; }
            final fwData = await dfuService.downloadFirmware(latest);
            if (fwData == null) { setState(() => dfuInProgress = false); return; }

            final ok = await dfuService.performDfu(
              unitId: -1, firmwareData: fwData,
              expectedSize: latest.size, targetVersion: latest.version,
              batteryPct: batPct,
            );
            setState(() {
              dfuInProgress = false;
              if (ok) {
                // Mark this LSM as updated so button changes to "up to date"
                final thisDocId = label == 'Indoor' ? indoorDocId : outdoorDocId;
                if (thisDocId != null) {
                  installedVersions[thisDocId] = latest.version;
                }
                // Recalculate flash state — stop if no more updates needed
                bool stillNeedsUpdate = false;
                if (indoorDocId != null && (installedVersions[indoorDocId] ?? 0) < latest.version) stillNeedsUpdate = true;
                if (outdoorDocId != null && (installedVersions[outdoorDocId] ?? 0) < latest.version) stillNeedsUpdate = true;
                if (!stillNeedsUpdate) {
                  flashTimer?.cancel();
                  flashTimer = null;
                  flashOn = true;
                } else {
                  // Scroll to the other LSM's flashing button
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (scrollController.hasClients) {
                      scrollController.animateTo(
                        scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
              }
            });
          }

          return AlertDialog(
            title: Text(
              '${room.name} Door',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: !dfuInProgress ? SingleChildScrollView(
              controller: scrollController,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (indoorDocId != null) ...[
                  Row(
                    children: [
                      const Text('Indoor  ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      BatteryUtils.batteryWidget(batteryPercent[indoorDocId] ?? 0),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Auto / Manual toggle
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade900,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () { setState(() => autoMode1 = true); saveSettings(); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: autoMode1 ? Colors.green.shade700 : Colors.transparent,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_fix_high, size: 16, color: autoMode1 ? Colors.white : Colors.grey),
                                      const SizedBox(width: 6),
                                      Text('Auto', style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: autoMode1 ? Colors.white : Colors.grey,
                                      )),
                                    ],
                                  ),
                                  if (autoMode1) const Text('Recommended', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () { setState(() => autoMode1 = false); saveSettings(); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: !autoMode1 ? Colors.blueGrey.shade700 : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.tune, size: 16, color: !autoMode1 ? Colors.white : Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('Manual', style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !autoMode1 ? Colors.white : Colors.grey,
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (autoMode1) ...[
                    // Auto mode — show info, hide manual controls
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_fix_high, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text('Smart Power Management', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your hub automatically finds the best signal strength for your setup. '
                            'It uses the lowest power needed for reliable communication, giving you the longest battery life.',
                            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.signal_cellular_alt, size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Current: ${powerLevelName(powerLevel1)}',
                                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Manual mode — show power level radios + high perf toggle
                    const Text(
                      'Set power level to lowest working value to extend battery life.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    const Text('Indoor Power Level:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    RadioListTile<int>(title: const Text('Low'), subtitle: const Text('Best battery life, hub must be close'), value: 1, groupValue: powerLevel1, dense: true, onChanged: (v) { setState(() => powerLevel1 = v!); saveSettings(); }),
                    RadioListTile<int>(title: const Text('Medium-Low'), subtitle: const Text('Good battery, short range'), value: 2, groupValue: powerLevel1, dense: true, onChanged: (v) { setState(() => powerLevel1 = v!); saveSettings(); }),
                    RadioListTile<int>(title: const Text('Medium'), subtitle: const Text('Balanced battery and range'), value: 3, groupValue: powerLevel1, dense: true, onChanged: (v) { setState(() => powerLevel1 = v!); saveSettings(); }),
                    RadioListTile<int>(title: const Text('High'), subtitle: const Text('Longer range, more battery use'), value: 4, groupValue: powerLevel1, dense: true, onChanged: (v) { setState(() => powerLevel1 = v!); saveSettings(); }),
                    RadioListTile<int>(title: const Text('Maximum'), subtitle: const Text('Best range, most battery use'), value: 5, groupValue: powerLevel1, dense: true, onChanged: (v) { setState(() => powerLevel1 = v!); saveSettings(); }),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('High Performance Power Mode'),
                      subtitle: const Text('Faster response, higher battery use'),
                      value: !systemOff1,
                      activeColor: Colors.orange,
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.shade700,
                      onChanged: (value) {
                        if (value) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Enable High Performance Mode?'),
                              content: const Text(
                                'This will reduce battery life by approximately 30% '
                                'but will make the device respond faster.\n\n'
                                'Only enable this if you are experiencing reliability issues '
                                'with detection.',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () { Navigator.of(ctx).pop(); setState(() => systemOff1 = false); saveSettings(); },
                                  child: const Text('Enable', style: TextStyle(color: Colors.orange)),
                                ),
                              ],
                            ),
                          );
                        } else {
                          setState(() => systemOff1 = true);
                          saveSettings();
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.battery_full, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Est. battery: ${estimateBatteryLife(systemOff1, powerLevel1, opsPerDay)}',
                            style: const TextStyle(fontSize: 14, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!dfuInProgress)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: (latestFwVersion > 0 && (installedVersions[indoorDocId] ?? 0) >= latestFwVersion)
                        ? Text(
                            'Indoor firmware is up to date (v$latestFwVersion)',
                            style: const TextStyle(fontSize: 13, color: Colors.green, fontStyle: FontStyle.italic),
                          )
                        : AnimatedOpacity(
                            opacity: flashOn ? 1.0 : 0.3,
                            duration: const Duration(milliseconds: 400),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.system_update, size: 16, color: Colors.white),
                                label: const Text('Update Indoor Firmware', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                onPressed: () => runDfu('Indoor'),
                              ),
                            ),
                          ),
                    ),
                ],
                if (outdoorDocId != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Outdoor  ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      BatteryUtils.batteryWidget(batteryPercent[outdoorDocId] ?? 0),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Auto / Manual toggle
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade900,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () { setState(() => autoMode2 = true); saveSettings(); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: autoMode2 ? Colors.green.shade700 : Colors.transparent,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_fix_high, size: 16, color: autoMode2 ? Colors.white : Colors.grey),
                                      const SizedBox(width: 6),
                                      Text('Auto', style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: autoMode2 ? Colors.white : Colors.grey,
                                      )),
                                    ],
                                  ),
                                  if (autoMode2) const Text('Recommended', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () { setState(() => autoMode2 = false); saveSettings(); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: !autoMode2 ? Colors.blueGrey.shade700 : Colors.transparent,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.tune, size: 16, color: !autoMode2 ? Colors.white : Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('Manual', style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !autoMode2 ? Colors.white : Colors.grey,
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (autoMode2) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_fix_high, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text('Smart Power Management', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your hub automatically finds the best signal strength for your setup. '
                            'It uses the lowest power needed for reliable communication, giving you the longest battery life.',
                            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.signal_cellular_alt, size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Current: ${powerLevelName(powerLevel2)}',
                                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Set power level to lowest working value to extend battery life.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    const Text('Outdoor Power Level:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    RadioListTile<int>(title: const Text('Low'), subtitle: const Text('Best battery life, hub must be close'), value: 1, groupValue: powerLevel2, dense: true, onChanged: (v) { setState(() => powerLevel2 = v!); saveSettings(); }),
                    RadioListTile<int>(title: const Text('Medium-Low'), subtitle: const Text('Good battery, short range'), value: 2, groupValue: powerLevel2, dense: true, onChanged: (v) { setState(() => powerLevel2 = v!); saveSettings(); }),
                    RadioListTile<int>(title: const Text('Medium'), subtitle: const Text('Balanced battery and range'), value: 3, groupValue: powerLevel2, dense: true, onChanged: (v) { setState(() => powerLevel2 = v!); saveSettings(); }),
                    RadioListTile<int>(title: const Text('High'), subtitle: const Text('Longer range, more battery use'), value: 4, groupValue: powerLevel2, dense: true, onChanged: (v) { setState(() => powerLevel2 = v!); saveSettings(); }),
                    RadioListTile<int>(title: const Text('Maximum'), subtitle: const Text('Best range, most battery use'), value: 5, groupValue: powerLevel2, dense: true, onChanged: (v) { setState(() => powerLevel2 = v!); saveSettings(); }),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('High Performance Power Mode'),
                      subtitle: const Text('Faster response, higher battery use'),
                      value: !systemOff2,
                      activeColor: Colors.orange,
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.shade700,
                      onChanged: (value) {
                        if (value) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Enable High Performance Mode?'),
                              content: const Text(
                                'This will reduce battery life by approximately 30% '
                                'but will make the device respond faster.\n\n'
                                'Only enable this if you are experiencing reliability issues '
                                'with detection.',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () { Navigator.of(ctx).pop(); setState(() => systemOff2 = false); saveSettings(); },
                                  child: const Text('Enable', style: TextStyle(color: Colors.orange)),
                                ),
                              ],
                            ),
                          );
                        } else {
                          setState(() => systemOff2 = true);
                          saveSettings();
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.battery_full, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Est. battery: ${estimateBatteryLife(systemOff2, powerLevel2, opsPerDay)}',
                            style: const TextStyle(fontSize: 14, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!dfuInProgress)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: (latestFwVersion > 0 && (installedVersions[outdoorDocId] ?? 0) >= latestFwVersion)
                        ? Text(
                            'Outdoor firmware is up to date (v$latestFwVersion)',
                            style: const TextStyle(fontSize: 13, color: Colors.green, fontStyle: FontStyle.italic),
                          )
                        : AnimatedOpacity(
                            opacity: flashOn ? 1.0 : 0.3,
                            duration: const Duration(milliseconds: 400),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.system_update, size: 16, color: Colors.white),
                                label: const Text('Update Outdoor Firmware', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                onPressed: () => runDfu('Outdoor'),
                              ),
                            ),
                          ),
                    ),
                ],
                // Matter device info (if any)
                if (hasMatterDevices) ...[
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.home, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Text('Matter Devices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Connected via Apple Home',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ...deviceDocs.where((d) => d.id.startsWith('matter_')).map((doc) {
                    final pct = batteryPercent[doc.id] ?? 0;
                    final data = doc.data() as Map<String, dynamic>;
                    final deviceName = (data['deviceName'] as String?)?.trim().isNotEmpty == true
                        ? data['deviceName'] as String
                        : '${doc.id.replaceFirst('matter_', '').substring(0, 8)}…';
                    final currentFw = data['firmwareVersion'] as String? ?? '';
                    final latestFwVersion = _matterFwInfo?.version;
                    final currentFwInt = _parseMatterFwVersion(currentFw);
                    final updateAvailable = latestFwVersion != null
                        && (currentFwInt == null || latestFwVersion > currentFwInt);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.lock, color: Colors.grey[700], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(deviceName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          ),
                          if (updateAvailable)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: AnimatedOpacity(
                                opacity: flashOn ? 1.0 : 0.3,
                                duration: const Duration(milliseconds: 400),
                                child: const Icon(Icons.system_update,
                                    color: Colors.orange, size: 20),
                              ),
                            ),
                          if (pct > 0) BatteryUtils.batteryWidget(pct)
                          else Text('—',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          IconButton(
                            icon: Icon(Icons.more_vert, color: Colors.grey[800], size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Options',
                            onPressed: () => _openMatterDeviceOptions(doc),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                if (hasHubDevices)
                  const Text(
                    'Estimates based on 10 operations per day.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
            ) :
            // ===== DFU IN PROGRESS — replace entire content =====
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<DfuState>(
                    valueListenable: dfuService.state,
                    builder: (_, dfuState, __) {
                      IconData icon;
                      Color color;
                      switch (dfuState) {
                        case DfuState.waitingForKeyTurn:
                          icon = Icons.vpn_key;
                          color = Colors.orange;
                          break;
                        case DfuState.hubTriggering:
                          icon = Icons.hub;
                          color = Colors.blue;
                          break;
                        case DfuState.scanningForDfuDevice:
                        case DfuState.connectingToDfuDevice:
                          icon = Icons.bluetooth_searching;
                          color = Colors.blue;
                          break;
                        case DfuState.transferring:
                          icon = Icons.upload;
                          color = Colors.orange;
                          break;
                        case DfuState.completing:
                          icon = Icons.pending;
                          color = Colors.orange;
                          break;
                        case DfuState.success:
                          icon = Icons.check_circle;
                          color = Colors.green;
                          break;
                        case DfuState.failed:
                          icon = Icons.error;
                          color = Colors.red;
                          break;
                        case DfuState.downloadingFirmware:
                          icon = Icons.cloud_download;
                          color = Colors.orange;
                          break;
                        default:
                          icon = Icons.system_update;
                          color = Colors.orange;
                      }
                      return Icon(icon, size: 48, color: color);
                    },
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<String>(
                    valueListenable: dfuService.statusMessage,
                    builder: (_, msg, __) => Text(
                      msg,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<double>(
                    valueListenable: dfuService.progress,
                    builder: (_, prog, __) => Column(
                      children: [
                        SizedBox(
                          height: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: prog,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(prog * 100).toInt()}%',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Do not close the app or move away from the door.',
                    style: TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            ), // SizedBox
            actions: [
              TextButton(
                onPressed: dfuInProgress ? null : () {
                  flashTimer?.cancel();
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
            ],
          );
        });
      },
    );
  }

  // Function to show confirmation dialog
  Future<void> showDeleteConfirmationDialog(
      String roomId, String userId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Door?'),
          content: const Text('This will remove the door and all its history. You can undo this for a few seconds after deletion.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await deleteRoom(roomId, userId);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: const Text('Door deleted'),
                        duration: const Duration(seconds: 8),
                        action: SnackBarAction(
                          label: 'UNDO',
                          textColor: Colors.yellow,
                          onPressed: () async {
                            await undoDeleteRoom();
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Door restored'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  buildRoomsPage() {
    // getLightSettingsFromFirestore();
    return MomentumBuilder(
        controllers: const [
          DataController,
          AuthenticationController,
        ],
        builder: (context, snapshot) {
          // var dataModel = snapshot<DataModel>();
          // // var dataController = dataModel.controller;
          var authModel = snapshot<AuthenticationModel>();
          var authController = authModel.controller;
          // final devices = dataModel.devicesSnapshot?.docs ?? [];

          // print("devices" + devices.toString());
          // currentAccount = dataModel.account;
          // print("home dataModel : " + currentAccount!.uid);

          return DefaultTabController(
            length: 2,
            child: Stack(
              children: [
                Scaffold(
              backgroundColor: const Color.fromARGB(255, 43, 43, 43),
              appBar: AppBar(
                elevation: 0,
                automaticallyImplyLeading: false,
                backgroundColor: const Color.fromARGB(255, 43, 43, 43),
                title: const Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(
                      ColorUtils.colorWhite,
                    ),
                  ),
                ),
                actions: [
                  // Need Help? button
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const ChatScreen(),
                      ));
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 33, 150, 243),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.help_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Need Help?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Logo
                  Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    width: 140,
                    height: 100,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5)),
                    child: Image.asset(
                      "assets/images/logo.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  )
                ],
                centerTitle: false,
                bottom: AppBar(
                  elevation: 0,
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  backgroundColor: const Color.fromARGB(255, 43, 43, 43),
                  title: const TabBar(
                    unselectedLabelColor: Color(ColorUtils.colorGrey),
                    indicatorColor: Colors.transparent,
                    tabs: [
                      Center(
                        child: Text("MY HOME"),
                      ),
                      Center(
                        child: Text("SHARED"),
                      ),
                    ],
                  ),
                  actions: [
                    GestureDetector(
                      onTap: () {
                        // Log plus button tapped for pairing analytics (fire and forget)
                        try {
                          PairingAnalyticsService().logPlusButtonTapped();
                        } catch (e) {
                          print('Error logging plus button tap: $e');
                        }

                        showModalBottomSheet(
                          context: context,
                          backgroundColor: const Color(ColorUtils.color2),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 8),
                                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                                const SizedBox(height: 16),
                                ListTile(
                                  leading: const Icon(Icons.router, color: Colors.white70),
                                  title: const Text('Add Hub', style: TextStyle(color: Colors.white)),
                                  subtitle: const Text('Pair a Locksure Hub via Bluetooth', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) => const AddHubScreen(),
                                    ));
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.home, color: Colors.white70),
                                  title: const Text('Add Matter Device', style: TextStyle(color: Colors.white)),
                                  subtitle: const Text('Pair via Apple Home or Google Home', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => const AddMatterDeviceScreen(),
                                    ));
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _lightSettingColour,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 18,
                    )
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  Column(
                    children: [
                      Expanded(
                        flex: 10,
                        child: StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('rooms')
                                .where("userId",
                                    isEqualTo:
                                        FirebaseAuth.instance.currentUser!.uid)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError) {
                                print('Error loading rooms: ${snapshot.error}');
                                return const Center(
                                  child: Text("Error loading rooms"),
                                );
                              }

                              if (snapshot.data == null ||
                                  snapshot.data!.docs.isEmpty) {
                                // Show onboarding overlay when no rooms
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && !_onboardingDismissed && !_showOnboardingOverlay) {
                                    setState(() {
                                      _showOnboardingOverlay = true;
                                    });
                                  }
                                });
                                return const Center(
                                  child: Text("No Rooms Registered"),
                                );
                              }

                              // Hide overlay if rooms exist
                              if (_showOnboardingOverlay) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    setState(() {
                                      _showOnboardingOverlay = false;
                                    });
                                  }
                                });
                              }

                              // Sort rooms by displayOrder if available, otherwise by creation order
                              var sortedDocs = snapshot.data!.docs.toList();
                              sortedDocs.sort((a, b) {
                                final aOrder = a.data()['displayOrder'] ?? 0;
                                final bOrder = b.data()['displayOrder'] ?? 0;
                                return aOrder.compareTo(bOrder);
                              });

                              // var data = snapshot.data; // Unused variable

                              // Compute a per-device tile height that keeps bottom padding ~<=10px
                              final media = MediaQuery.of(context);
                              final screenWidth = media.size.width;
                              final screenHeight = media.size.height;
                              final textScale = media.textScaleFactor;
                              const horizontalPadding = 15.0; // grid padding
                              const crossAxisSpacing = 20.0;
                              final tileWidth = (screenWidth -
                                      (horizontalPadding * 2) -
                                      crossAxisSpacing) /
                                  2.0;

                              // Detect if device is a tablet (roughly: width > 600dp or both dimensions > 600)
                              final isTablet = screenWidth > 600 ||
                                  (screenWidth > 500 && screenHeight > 800);

                              // Estimate content height (icon, texts, two button rows, spacing)
                              // Base tuned to this layout; scale slightly with text for accessibility.
                              // Tablets need more height due to different text scaling and layout constraints
                              // Overflow was 62px, so we need additional height + padding (10px bottom)
                              final baseContent = isTablet
                                  ? 590.0 // Increased for tablets to prevent overflow (was 482, overflow 62, need ~72+ extra)
                                  : 482.0; // Phone baseline
                              final tileHeight =
                                  baseContent * textScale.clamp(1.0, 1.3);
                              // Using mainAxisExtent below; no aspect ratio needed.

                              // Unified horizontal gap for button rows
                              final buttonGap = 10.w;

                              return ReorderableGridView.builder(
                                padding:
                                    const EdgeInsets.all(horizontalPadding),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: tileHeight,
                                  crossAxisSpacing: crossAxisSpacing,
                                  mainAxisSpacing: 20,
                                ),
                                itemCount: sortedDocs.length,
                                onReorder: (oldIndex, newIndex) async {
                                  // Handle reordering logic here
                                  print(
                                      'Reordered from $oldIndex to $newIndex');

                                  // Get the current list of rooms
                                  List<
                                          QueryDocumentSnapshot<
                                              Map<String, dynamic>>> rooms =
                                      sortedDocs;

                                  // Remove the item from the old position and insert at new position
                                  if (oldIndex < newIndex) {
                                    newIndex -= 1;
                                  }

                                  final item = rooms.removeAt(oldIndex);
                                  rooms.insert(newIndex, item);

                                  // Update displayOrder for all rooms
                                  for (int i = 0; i < rooms.length; i++) {
                                    await FirebaseFirestore.instance
                                        .collection('rooms')
                                        .doc(rooms[i].id)
                                        .update({'displayOrder': i});
                                  }

                                  print(
                                      'Updated display order for ${rooms.length} rooms');
                                },
                                itemBuilder: (context, index) {
                                  var doc = sortedDocs[index];
                                  var room = Room.fromDocument(doc);
                                  return GestureDetector(
                                    key: ValueKey(room.roomId),
                                    onTap: () => showDoorDetailPopup(room),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(255, 55, 55, 55),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Color(roomStateColor(room.state)),
                                            width: 2),

                                        // boxShadow: [
                                        //   BoxShadow(
                                        //       blurRadius: 4,
                                        //       color: Theme.of(context).accentColor)
                                        // ],
                                        // border: Border.all(
                                        //     color: Theme.of(context).accentColor),
                                      ),
                                      child: Stack(
                                        children: [
                                          // Battery indicator removed from the card's top-right corner. It now lives inside the battery button below.
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              // ===== GROUP 1: Lock Icon =====
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(15),
                                                margin: const EdgeInsets.only(
                                                  top: 15,
                                                ),
                                                decoration: BoxDecoration(
                                                    color: const Color.fromARGB(255, 70, 70, 70),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                        color: Color(roomStateColor(room.state)),
                                                        width: 1)),
                                                child: Center(
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Icon(
                                                        room.state == 1
                                                            ? Icons.lock
                                                            : Icons.lock_open,
                                                        size: 100,
                                                        color: Color(roomStateColor(room.state)),
                                                      ),
                                                      if (currentIndex != 1 &&
                                                          room.sharedWith
                                                              .isNotEmpty)
                                                        Transform.translate(
                                                          offset: const Offset(
                                                              0, 60),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(6),
                                                            decoration:
                                                                const BoxDecoration(
                                                              color:
                                                                  Colors.green,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            constraints:
                                                                const BoxConstraints(
                                                              minWidth: 30,
                                                              minHeight: 30,
                                                            ),
                                                            child: Text(
                                                              room.sharedWith
                                                                  .length
                                                                  .toString(),
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // ===== GROUP 2: Name + State =====
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: buttonGap),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      room.name,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18.sp,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Text(
                                                      room.state == 0
                                                          ? "Not Set"
                                                          : (room.state == 2 || room.state == 4)
                                                              ? "Unlocked"
                                                              : room.state == 1
                                                                  ? "Locked"
                                                                  : room.state == 3
                                                                      ? "Open"
                                                                      : "Not Set",
                                                      style: TextStyle(
                                                        color: Color(roomStateColor(room.state)),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16.sp,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // ===== GROUP 3: Last Operation =====
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: buttonGap),
                                                child: StreamBuilder<
                                                    QuerySnapshot>(
                                                      stream: FirebaseFirestore
                                                          .instance
                                                          .collection(
                                                              'notifications')
                                                          .where('roomId',
                                                              isEqualTo:
                                                                  room.roomId)
                                                          .orderBy(
                                                              'received_at',
                                                              descending: true)
                                                          .limit(1)
                                                          .snapshots(),
                                                      builder: (context,
                                                          notifSnapshot) {
                                                        if (notifSnapshot
                                                                .connectionState ==
                                                            ConnectionState
                                                                .waiting) {
                                                          return const CircularProgressIndicator();
                                                        }
                                                        if (notifSnapshot.hasError ||
                                                            !notifSnapshot
                                                                .hasData ||
                                                            notifSnapshot.data!
                                                                .docs.isEmpty) {
                                                          return const Column(
                                                            children: [
                                                              Text(
                                                                '--',
                                                                style: TextStyle(
                                                                    fontSize: 13,
                                                                    color: Colors.white54,
                                                                    fontWeight: FontWeight.w500),
                                                              ),
                                                              SizedBox(height: 4),
                                                              Text(
                                                                'Last Operation:',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: Colors
                                                                        .white38,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold),
                                                              ),
                                                              Text(
                                                                'Not Set',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: Colors
                                                                        .white38),
                                                              ),
                                                            ],
                                                          );
                                                        }
                                                        final notif =
                                                            notifSnapshot.data!
                                                                    .docs.first
                                                                    .data()
                                                                as Map<String,
                                                                    dynamic>;
                                                        final msg =
                                                            notif['message']
                                                                as Map<String,
                                                                    dynamic>?;
                                                        String? isoString = msg !=
                                                                null
                                                            ? msg['received_at']
                                                                as String?
                                                            : null;
                                                        DateTime? date;
                                                        if (isoString != null) {
                                                          try {
                                                            // Parse UTC timestamp and convert to user's local timezone
                                                            date = DateTime.parse(isoString).toLocal();
                                                          } catch (e) {
                                                            print(
                                                                'Failed to parse message.received_at: '
                                                                '[31m$isoString[0m');
                                                          }
                                                        }
                                                        final formatted = date !=
                                                                null
                                                            ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}'
                                                            : 'Unknown';
                                                        final relativeTime = date != null
                                                            ? getRelativeTime(date)
                                                            : '';
                                                        return Column(
                                                          children: [
                                                            Text(
                                                              relativeTime,
                                                              style: const TextStyle(
                                                                  fontSize: 13,
                                                                  color: Colors.white54,
                                                                  fontWeight: FontWeight.w500),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            const Text(
                                                              'Last Operation:',
                                                              style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .white38,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold),
                                                            ),
                                                            Text(
                                                              formatted,
                                                              style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .white38),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                              ),
                                              // ===== GROUP 4: Buttons =====
                                              Column(
                                                children: [
                                                  // Full-width Battery Button — with update badge
                                                  Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                                                    child: StreamBuilder<DocumentSnapshot>(
                                                      stream: FirebaseFirestore.instance
                                                          .collection('rooms')
                                                          .doc(room.roomId)
                                                          .snapshots(),
                                                      builder: (context, roomSnap) {
                                                        int updatesAvailable = 0;
                                                        if (_latestLsmFwVersion > 0 && roomSnap.hasData && roomSnap.data!.exists) {
                                                          final data = roomSnap.data!.data() as Map<String, dynamic>?;
                                                          final lsmVersions = data?['lsmVersions'] as Map<String, dynamic>? ?? {};
                                                          for (var v in lsmVersions.values) {
                                                            final ver = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
                                                            if (ver < _latestLsmFwVersion) updatesAvailable++;
                                                          }
                                                        }
                                                        return Stack(
                                                          clipBehavior: Clip.none,
                                                          children: [
                                                            SizedBox(
                                                              width: double.infinity,
                                                              height: 52.h,
                                                              child: ElevatedButton(
                                                                onPressed: () async {
                                                                  await showBatteryPowerDialog(room);
                                                                },
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: const Color.fromARGB(255, 65, 65, 65),
                                                                  elevation: 4,
                                                                  shadowColor: Colors.black54,
                                                                  padding: EdgeInsets.zero,
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(12),
                                                                  ),
                                                                ),
                                                                child: FutureBuilder<List<int>>(
                                                                  future: _getDeviceBatteries(room.roomId),
                                                                  builder: (context, batSnap) {
                                                                    final bats = batSnap.data ?? [];
                                                                    if (bats.isEmpty) {
                                                                      return Text('--', style: TextStyle(fontSize: 12.sp, color: Colors.black45));
                                                                    }
                                                                    if (bats.length == 1) {
                                                                      return Padding(
                                                                        padding: const EdgeInsets.all(5),
                                                                        child: _batteryColumn(bats[0]),
                                                                      );
                                                                    }
                                                                    // Two LSMs — tighter vertical padding
                                                                    return Padding(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          _batteryColumn(bats[0], compact: true),
                                                                          const SizedBox(width: 16),
                                                                          _batteryColumn(bats[1], compact: true),
                                                                        ],
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                              ),
                                                            ),
                                                            // Update badge (orange dot)
                                                            if (updatesAvailable > 0)
                                                              Positioned(
                                                                right: -4,
                                                                top: -4,
                                                                child: Container(
                                                                  padding: const EdgeInsets.all(4),
                                                                  decoration: const BoxDecoration(
                                                                    color: Colors.orange,
                                                                    shape: BoxShape.circle,
                                                                  ),
                                                                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                                                  child: Text(
                                                                    '$updatesAvailable',
                                                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                                    textAlign: TextAlign.center,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  SizedBox(height: 8.h),
                                                  // Bottom row: Edit, Share, Delete — same width as battery button
                                                  Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                                                    child: Row(
                                                      children: [
                                                        // Edit Button
                                                        Expanded(
                                                          child: SizedBox(
                                                            height: 36.h,
                                                            child: ElevatedButton(
                                                              onPressed: () async {
                                                                final name = await openRenameDialog();
                                                                if (name == null || name.isEmpty) return;
                                                                setState(() => this.name);
                                                                FirebaseFirestore.instance
                                                                    .collection("rooms")
                                                                    .doc(room.roomId)
                                                                    .update({"name": name.toUpperCase()});
                                                                final db = FirebaseFirestore.instance;
                                                                var result = await db
                                                                    .collection('users')
                                                                    .doc(room.userId)
                                                                    .collection('devices')
                                                                    .where('roomId', isEqualTo: room.roomId)
                                                                    .get();
                                                                for (var res in result.docs) {
                                                                  db.collection('devices').doc(res.id).get().then((value) {
                                                                    bool isIndoor = value.get('isIndoor');
                                                                    db.collection('devices').doc(res.id).update({
                                                                      'deviceName': isIndoor ? name.toUpperCase() : name
                                                                    });
                                                                  });
                                                                }
                                                              },
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: const Color.fromARGB(255, 65, 65, 65),
                                                                elevation: 4,
                                                                shadowColor: Colors.black54,
                                                                padding: EdgeInsets.zero,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(10),
                                                                ),
                                                              ),
                                                              child: Icon(Icons.edit, color: Colors.blue, size: 18.sp),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 5),
                                                        // Share Button
                                                        Expanded(
                                                          child: SizedBox(
                                                            height: 36.h,
                                                            child: ElevatedButton(
                                                              onPressed: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (context) => ShareRoomPage(
                                                                      roomId: room.roomId,
                                                                      roomName: room.name,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: const Color.fromARGB(255, 65, 65, 65),
                                                                elevation: 4,
                                                                shadowColor: Colors.black54,
                                                                padding: EdgeInsets.zero,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(10),
                                                                ),
                                                              ),
                                                              child: Icon(Icons.share, color: Colors.blue, size: 18.sp),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 5),
                                                        // Delete Button
                                                        Expanded(
                                                          child: SizedBox(
                                                            height: 36.h,
                                                            child: ElevatedButton(
                                                              onPressed: () {
                                                                showDeleteConfirmationDialog(room.roomId, room.userId);
                                                              },
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: const Color.fromARGB(255, 65, 65, 65),
                                                                elevation: 4,
                                                                shadowColor: Colors.black54,
                                                                padding: EdgeInsets.zero,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(10),
                                                                ),
                                                              ),
                                                              child: Icon(Icons.delete, color: Colors.red, size: 18.sp),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // Bottom padding: max 10px from last icon as per requirements
                                              SizedBox(height: 10.h),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                      ),
                      // Expanded(
                      //   child: Container(),
                      //   flex: 1,
                      // ),

                      // Expanded(
                      //   child: Container(),
                      //   flex: 1,
                      // ),

                      // Expanded(
                      //   flex: 1,
                      //   child: Center(
                      //     child: Text(
                      //       "Security Level",
                      //       style: TextStyle(
                      //         fontSize: 20,
                      //         fontWeight: FontWeight.w700,
                      //         color: Colors.white70,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // Expanded(
                      //   child: NumberStepper(
                      //       lineColor: Color(ColorUtils.color3),
                      //       activeStepColor: Theme.of(context).accentColor,
                      //       activeStepBorder
                      //       stepColor: Color(
                      //         ColorUtils.color3,
                      //       ),
                      //       lineDotRadius: 3,
                      //       activeStepBorderWidth: 3,
                      //       lineLength: 60,
                      //       numbers: [
                      //         1,
                      //         2,
                      //         3,
                      //         4,
                      //       ]),
                      //   flex: 1,
                      // ),
                    ],
                  ),

                  // SHARED PAGE STARTS HERE
                  Column(
                    children: [
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('rooms')
                              .where("sharedWith",
                                  arrayContains:
                                      FirebaseAuth.instance.currentUser!.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            // Debug information
                            print("\n=== SHARED ROOMS DEBUG ===");
                            print(
                                "Current user ID: ${FirebaseAuth.instance.currentUser!.uid}");
                            print(
                                "Current user email: ${FirebaseAuth.instance.currentUser!.email}");
                            print(
                                "Connection state: ${snapshot.connectionState}");
                            print("Has error: ${snapshot.hasError}");
                            if (snapshot.hasError) {
                              print("Error: ${snapshot.error}");
                            }
                            print("Has data: ${snapshot.hasData}");
                            print(
                                "Number of rooms: ${snapshot.data?.docs.length ?? 0}");

                            if (snapshot.data != null) {
                              for (var doc in snapshot.data!.docs) {
                                print("\nRoom Details:");
                                print("Room ID: ${doc.id}");
                                print("Room Name: ${doc.data()['name']}");
                                print(
                                    "Shared With: ${doc.data()['sharedWith']}");
                                print("Owner ID: ${doc.data()['userId']}");
                              }
                            }
                            print("=========================\n");

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError) {
                              print(
                                  'Error loading shared rooms: ${snapshot.error}');
                              return const Center(
                                child: Text("Error loading shared rooms",
                                    style: TextStyle(color: Colors.white)),
                              );
                            }

                            if (snapshot.data == null ||
                                snapshot.data!.docs.isEmpty) {
                              return const Center(
                                child: Text("No Shared Rooms",
                                    style: TextStyle(color: Colors.white)),
                              );
                            }

                            // Sort shared rooms by displayOrder if available, otherwise by creation order
                            var sortedSharedDocs = snapshot.data!.docs.toList();
                            sortedSharedDocs.sort((a, b) {
                              final aOrder = a.data()['displayOrder'] ?? 0;
                              final bOrder = b.data()['displayOrder'] ?? 0;
                              return aOrder.compareTo(bOrder);
                            });

                            // var data = snapshot.data; // Unused variable

                            return ReorderableGridView.builder(
                              padding: EdgeInsets.all(20
                                  .w), // Increased from 15.w for better edge spacing
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio:
                                    0.5, // Decreased from 0.65 to make cards much taller so all content fits without scrolling
                                crossAxisSpacing: 20
                                    .w, // Increased from 20.w for better card separation
                                mainAxisSpacing: 20
                                    .h, // Increased from 20.h for better vertical separation
                              ),
                              itemCount: sortedSharedDocs.length,
                              onReorder: (oldIndex, newIndex) async {
                                // Handle reordering logic here
                                print(
                                    'Reordered shared room from $oldIndex to $newIndex');

                                // Get the current list of shared rooms
                                List<
                                        QueryDocumentSnapshot<
                                            Map<String, dynamic>>> rooms =
                                    sortedSharedDocs;

                                // Remove the item from the old position and insert at new position
                                if (oldIndex < newIndex) {
                                  newIndex -= 1;
                                }

                                final item = rooms.removeAt(oldIndex);
                                rooms.insert(newIndex, item);

                                // Update displayOrder for all shared rooms
                                for (int i = 0; i < rooms.length; i++) {
                                  await FirebaseFirestore.instance
                                      .collection('rooms')
                                      .doc(rooms[i].id)
                                      .update({'displayOrder': i});
                                }

                                print(
                                    'Updated display order for ${rooms.length} shared rooms');
                              },
                              itemBuilder: (context, index) {
                                var doc = sortedSharedDocs[index];
                                var room = Room.fromDocument(doc);
                                return GestureDetector(
                                  key: ValueKey(room.roomId),
                                  // onTap: () {
                                  //   Navigator.of(context)
                                  //       .push(MaterialPageRoute(
                                  //     builder: (context) {
                                  //       return RoomDetailScreen(
                                  //           room: room);
                                  //     },
                                  //   ));
                                  // },

                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(255, 55, 55, 55),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Color(room.state == 0
                                              ? ColorUtils.colorGrey
                                              : room.state == 2 &&
                                                      globals.lightSetting == 1
                                                  ? ColorUtils.colorRed
                                                  : room.state == 1 &&
                                                          globals.lightSetting ==
                                                              1
                                                      ? ColorUtils.colorGreen
                                                      : room.state == 3 &&
                                                              globals.lightSetting ==
                                                                  1
                                                          ? ColorUtils.colorRed
                                                          : room.state == 1
                                                              ? ColorUtils
                                                                  .colorGrey
                                                              : room.state ==
                                                                          2 &&
                                                                      globals.lightSetting ==
                                                                          2
                                                                  ? ColorUtils
                                                                      .colorAmber
                                                                  : room.state ==
                                                                              1 &&
                                                                          globals.lightSetting ==
                                                                              2
                                                                      ? ColorUtils
                                                                          .colorBlue
                                                                      : room.state == 3 &&
                                                                              globals.lightSetting ==
                                                                                  2
                                                                          ? ColorUtils
                                                                              .colorRed
                                                                          : room.state == 2 && globals.lightSetting == 3
                                                                              ? ColorUtils.colorAmber
                                                                              : room.state == 1 && globals.lightSetting == 3
                                                                                  ? ColorUtils.colorCyan
                                                                                  : room.state == 3 && globals.lightSetting == 3
                                                                                      ? ColorUtils.colorRed
                                                                                      : ColorUtils.colorRed),
                                          width: 2),

                                      // boxShadow: [
                                      //   BoxShadow(
                                      //       blurRadius: 4,
                                      //       color: Theme.of(context).accentColor)
                                      // ],
                                      // border: Border.all(
                                      //     color: Theme.of(context).accentColor),
                                    ),
                                    child: Stack(
                                      children: [
                                        SingleChildScrollView(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 25),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                    color: const Color(
                                                        ColorUtils.colorWhite),
                                                    shape: BoxShape.circle,
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Colors.grey,
                                                        offset: Offset(0.0,
                                                            2.0), //(x,y) - Increased blur for better depth
                                                        blurRadius:
                                                            8.0, // Increased from 6.0 for better shadow
                                                      ),
                                                    ],
                                                    border: Border.all(
                                                        color: Color(room
                                                                    .state ==
                                                                1
                                                            ? ColorUtils
                                                                .colorGrey
                                                            : room.state == 2 &&
                                                                    globals.lightSetting ==
                                                                        1
                                                                ? ColorUtils
                                                                    .colorRed
                                                                : room.state ==
                                                                            1 &&
                                                                        globals.lightSetting ==
                                                                            1
                                                                    ? ColorUtils
                                                                        .colorGreen
                                                                    : room.state ==
                                                                                3 &&
                                                                            globals.lightSetting ==
                                                                                1
                                                                        ? ColorUtils
                                                                            .colorRed
                                                                        : room.state ==
                                                                                0
                                                                            ? ColorUtils.colorGrey
                                                                            : room.state == 2 && globals.lightSetting == 2
                                                                                ? ColorUtils.colorAmber
                                                                                : room.state == 1 && globals.lightSetting == 2
                                                                                    ? ColorUtils.colorBlue
                                                                                    : room.state == 3 && globals.lightSetting == 3
                                                                                        ? ColorUtils.colorRed
                                                                                        : room.state == 2 && globals.lightSetting == 3
                                                                                            ? ColorUtils.colorAmber
                                                                                            : room.state == 1 && globals.lightSetting == 3
                                                                                                ? ColorUtils.colorCyan
                                                                                                : room.state == 3 && globals.lightSetting == 3
                                                                                                    ? ColorUtils.colorRed
                                                                                                    : ColorUtils.colorRed),
                                                        width: 2)), // Increased from 1 for better border visibility
                                                child: Center(
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Icon(
                                                        room.state == 1
                                                            ? Icons.lock
                                                            : Icons.lock_open,
                                                        size: 90
                                                            .sp, // Increased from 100.sp for better proportion on modern phones
                                                        color: Color(room
                                                                    .state ==
                                                                0
                                                            ? ColorUtils
                                                                .colorGrey
                                                            : room.state == 2 &&
                                                                    globals.lightSetting ==
                                                                        1
                                                                ? ColorUtils
                                                                    .colorRed
                                                                : room.state ==
                                                                            1 &&
                                                                        globals.lightSetting ==
                                                                            1
                                                                    ? ColorUtils
                                                                        .colorGreen
                                                                    : room.state ==
                                                                                3 &&
                                                                            globals.lightSetting ==
                                                                                1
                                                                        ? ColorUtils
                                                                            .colorRed
                                                                        : room.state ==
                                                                                0
                                                                            ? ColorUtils.colorGrey
                                                                            : room.state == 2 && globals.lightSetting == 2
                                                                                ? ColorUtils.colorAmber
                                                                                : room.state == 1 && globals.lightSetting == 2
                                                                                    ? ColorUtils.colorBlue
                                                                                    : room.state == 3 && globals.lightSetting == 3
                                                                                        ? ColorUtils.colorRed
                                                                                        : room.state == 2 && globals.lightSetting == 3
                                                                                            ? ColorUtils.colorAmber
                                                                                            : room.state == 1 && globals.lightSetting == 3
                                                                                                ? ColorUtils.colorCyan
                                                                                                : room.state == 3 && globals.lightSetting == 3
                                                                                                    ? ColorUtils.colorRed
                                                                                                    : ColorUtils.colorRed),
                                                      ),
                                                      if (room.sharedWith
                                                          .isNotEmpty)
                                                        Container(),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                room.name,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              ShareRequestStatus(
                                                  roomId: room.roomId),
                                              Text(
                                                room.state == 0
                                                    ? "Not Set"
                                                    : (room.state == 2 || room.state == 4)
                                                        ? "Unlocked"
                                                        : room.state == 1
                                                            ? "Locked"
                                                            : room.state == 3
                                                                ? "Open"
                                                                : "Not Set",
                                                style: TextStyle(
                                                  color: Color(roomStateColor(room.state)),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      // Show confirmation dialog
                                                      showDialog(
                                                        context: context,
                                                        builder: (BuildContext
                                                            context) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                                'Remove Shared Access'),
                                                            content: const Text(
                                                                'Are you sure you want to remove your access to this shared room?'),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop(); // Close dialog
                                                                },
                                                                child: const Text(
                                                                    'Cancel'),
                                                              ),
                                                              TextButton(
                                                                onPressed:
                                                                    () async {
                                                                  try {
                                                                    // Remove current user from sharedWith array
                                                                    await FirebaseFirestore
                                                                        .instance
                                                                        .collection(
                                                                            'rooms')
                                                                        .doc(room
                                                                            .roomId)
                                                                        .update({
                                                                      'sharedWith':
                                                                          FieldValue
                                                                              .arrayRemove([
                                                                        FirebaseAuth
                                                                            .instance
                                                                            .currentUser!
                                                                            .uid
                                                                      ])
                                                                    });

                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(); // Close dialog
                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(
                                                                      const SnackBar(
                                                                          content:
                                                                              Text('Access removed successfully')),
                                                                    );
                                                                  } catch (e) {
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(); // Close dialog
                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(
                                                                      SnackBar(
                                                                          content:
                                                                              Text('Error removing access: $e')),
                                                                    );
                                                                  }
                                                                },
                                                                child: const Text(
                                                                    'Remove Access',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .red)),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors
                                                            .white,
                                                        fixedSize: Size(
                                                            52.w, 52.h),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 1,
                                                                vertical: 1),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        textStyle:
                                                            const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                    child: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  // Edit nickname button
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
                                                      // Get current nickname if exists
                                                      final roomDoc = await FirebaseFirestore.instance
                                                          .collection('rooms')
                                                          .doc(room.roomId)
                                                          .get();
                                                      String currentNickname = '';
                                                      if (roomDoc.exists) {
                                                        final nicknames = roomDoc.data()?['sharedNicknames'] as Map<String, dynamic>?;
                                                        if (nicknames != null && nicknames.containsKey(currentUserId)) {
                                                          currentNickname = nicknames[currentUserId] ?? '';
                                                        }
                                                      }

                                                      final nicknameController = TextEditingController(text: currentNickname);
                                                      final nickname = await showDialog<String>(
                                                        context: context,
                                                        builder: (BuildContext context) {
                                                          return AlertDialog(
                                                            title: const Text('Set Owner Nickname'),
                                                            content: TextField(
                                                              controller: nicknameController,
                                                              decoration: const InputDecoration(
                                                                hintText: 'Enter a friendly name',
                                                                labelText: 'Nickname',
                                                              ),
                                                              autofocus: true,
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () => Navigator.of(context).pop(),
                                                                child: const Text('Cancel'),
                                                              ),
                                                              TextButton(
                                                                onPressed: () => Navigator.of(context).pop(nicknameController.text),
                                                                child: const Text('Save'),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );

                                                      if (nickname != null) {
                                                        // Save nickname to room document
                                                        await FirebaseFirestore.instance
                                                            .collection('rooms')
                                                            .doc(room.roomId)
                                                            .set({
                                                          'sharedNicknames': {
                                                            currentUserId: nickname.isEmpty ? FieldValue.delete() : nickname
                                                          }
                                                        }, SetOptions(merge: true));

                                                        setState(() {}); // Refresh UI
                                                      }
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.white,
                                                        fixedSize: Size(52.w, 52.h),
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 1, vertical: 1),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        textStyle: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold)),
                                                    child: const Icon(
                                                      Icons.edit,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              StreamBuilder<DocumentSnapshot>(
                                                stream: FirebaseFirestore
                                                    .instance
                                                    .collection('rooms')
                                                    .doc(room.roomId)
                                                    .snapshots(),
                                                builder:
                                                    (context, roomSnapshot) {
                                                  return FutureBuilder<DocumentSnapshot>(
                                                    future: FirebaseFirestore
                                                        .instance
                                                        .collection('users')
                                                        .doc(room.userId)
                                                        .get(),
                                                    builder:
                                                        (context, userSnapshot) {
                                                      if (userSnapshot
                                                              .connectionState ==
                                                          ConnectionState.waiting) {
                                                        return const SizedBox(
                                                          height: 20,
                                                          width: 20,
                                                          child: CircularProgressIndicator(strokeWidth: 2),
                                                        );
                                                      }
                                                      if (userSnapshot.hasError ||
                                                          !userSnapshot.hasData ||
                                                          !userSnapshot.data!.exists) {
                                                        return const Text(
                                                            'Error loading owner');
                                                      }
                                                      final emails = userSnapshot
                                                          .data!['email'] as String;

                                                      // Check for nickname
                                                      String displayName = emails;
                                                      if (roomSnapshot.hasData && roomSnapshot.data!.exists) {
                                                        final roomData = roomSnapshot.data!.data() as Map<String, dynamic>?;
                                                        final nicknames = roomData?['sharedNicknames'] as Map<String, dynamic>?;
                                                        final currentUserId = FirebaseAuth.instance.currentUser!.uid;
                                                        if (nicknames != null && nicknames.containsKey(currentUserId)) {
                                                          final nickname = nicknames[currentUserId] as String?;
                                                          if (nickname != null && nickname.isNotEmpty) {
                                                            displayName = nickname;
                                                          }
                                                        }
                                                      }

                                                      return Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(horizontal: 5.0),
                                                            child: Center(
                                                              child: Text(
                                                                'This Door Belongs To:\n$displayName',
                                                                style:
                                                                    const TextStyle(
                                                                  color:
                                                                      Colors.black,
                                                                  fontSize: 11,
                                                                ),
                                                                textAlign: TextAlign.center,
                                                              ),
                                                            ),
                                                          ),
                                                      StreamBuilder<
                                                          QuerySnapshot>(
                                                        stream: FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'notifications')
                                                            .where('roomId',
                                                                isEqualTo:
                                                                    room.roomId)
                                                            .orderBy(
                                                                'received_at',
                                                                descending:
                                                                    true)
                                                            .limit(1)
                                                            .snapshots(),
                                                        builder: (context,
                                                            notifSnapshot) {
                                                          if (notifSnapshot
                                                                  .connectionState ==
                                                              ConnectionState
                                                                  .waiting) {
                                                            return const CircularProgressIndicator();
                                                          }
                                                          if (notifSnapshot.hasError ||
                                                              !notifSnapshot
                                                                  .hasData ||
                                                              notifSnapshot
                                                                  .data!
                                                                  .docs
                                                                  .isEmpty) {
                                                            return const Column(
                                                              children: [
                                                                Text(
                                                                  '--',
                                                                  style: TextStyle(
                                                                      fontSize: 13,
                                                                      color: Colors.black54,
                                                                      fontWeight: FontWeight.w500),
                                                                ),
                                                                SizedBox(height: 4),
                                                                Text(
                                                                  'Last Operation:',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: Colors
                                                                          .black45,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold),
                                                                ),
                                                                Text(
                                                                  'Not Set',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: Colors
                                                                          .black45),
                                                                ),
                                                              ],
                                                            );
                                                          }
                                                          final notif =
                                                              notifSnapshot
                                                                      .data!
                                                                      .docs
                                                                      .first
                                                                      .data()
                                                                  as Map<String,
                                                                      dynamic>;
                                                          final msg =
                                                              notif['message']
                                                                  as Map<String,
                                                                      dynamic>?;
                                                          String? isoString =
                                                              msg != null
                                                                  ? msg['received_at']
                                                                      as String?
                                                                  : null;
                                                          DateTime? date;
                                                          if (isoString !=
                                                              null) {
                                                            try {
                                                              // Parse UTC timestamp and convert to user's local timezone
                                                              date = DateTime.parse(isoString).toLocal();
                                                            } catch (e) {
                                                              print(
                                                                  'Failed to parse message.received_at: '
                                                                  '[31m$isoString[0m');
                                                            }
                                                          }
                                                          final formatted = date !=
                                                                  null
                                                              ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}'
                                                              : 'Unknown';
                                                          final relativeTime = date != null
                                                              ? getRelativeTime(date)
                                                              : '';
                                                          return Column(
                                                            children: [
                                                              Text(
                                                                relativeTime,
                                                                style: const TextStyle(
                                                                    fontSize: 13,
                                                                    color: Colors.black54,
                                                                    fontWeight: FontWeight.w500),
                                                              ),
                                                              const SizedBox(height: 4),
                                                              const Text(
                                                                'Last Operation:',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: Colors
                                                                        .black45,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold),
                                                              ),
                                                              Text(
                                                                formatted,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: Colors
                                                                        .black45),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  );
                                                    },
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                          ),
                                        ),
                                        // Shared icon in top left corner - tappable to show share info
                                        Positioned(
                                          top: 5,
                                          left: 5,
                                          child: GestureDetector(
                                            onTap: () async {
                                              // Fetch owner info
                                              final ownerDoc = await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(room.userId)
                                                  .get();
                                              String ownerEmail = 'Unknown';
                                              if (ownerDoc.exists && ownerDoc.data() != null) {
                                                ownerEmail = ownerDoc.data()!['email'] ?? 'Unknown';
                                              }

                                              // Try to get share date from room document
                                              final roomDoc = await FirebaseFirestore.instance
                                                  .collection('rooms')
                                                  .doc(room.roomId)
                                                  .get();
                                              String sharedDate = 'Unknown';
                                              if (roomDoc.exists && roomDoc.data()?['sharedAt'] != null) {
                                                final timestamp = roomDoc.data()!['sharedAt'];
                                                if (timestamp is Timestamp) {
                                                  final date = timestamp.toDate().toLocal();
                                                  sharedDate = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
                                                }
                                              }

                                              showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text('Shared Door Info'),
                                                    content: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text(
                                                          'Shared by:',
                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                        ),
                                                        Text(ownerEmail),
                                                        const SizedBox(height: 12),
                                                        const Text(
                                                          'Shared on:',
                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                        ),
                                                        Text(sharedDate),
                                                      ],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.of(context).pop(),
                                                        child: const Text('OK'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.share,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Battery icon in top right corner
                                        Positioned(
                                          top: 5,
                                          right: 5,
                                          child: StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('notifications')
                                                .where('roomId',
                                                    isEqualTo: room.roomId)
                                                .orderBy('received_at',
                                                    descending: true)
                                                .limit(1)
                                                .snapshots(),
                                            builder: (context, batterySnapshot) {
                                              if (batterySnapshot.hasData &&
                                                  batterySnapshot.data!.docs.isNotEmpty) {
                                                final notif = batterySnapshot.data!.docs.first.data()
                                                    as Map<String, dynamic>;
                                                final msg = notif['message'] as Map<String, dynamic>?;

                                                if (msg != null && msg['uplink_message'] != null) {
                                                  final uplinkMessage = msg['uplink_message'] as Map<String, dynamic>;
                                                  final decodedPayload = uplinkMessage['decoded_payload']
                                                      as Map<String, dynamic>?;

                                                  if (decodedPayload != null && decodedPayload['batVolts'] != null) {
                                                    final rawBatVolts = decodedPayload['batVolts'] as int;
                                                    final batVolts = BatteryUtils.calculateBatteryPercentage(rawBatVolts);

                                                    return Stack(
                                                      alignment: Alignment.center,
                                                      children: [
                                                        Icon(
                                                          batVolts > 90
                                                              ? Icons.battery_full_rounded
                                                              : batVolts > 75
                                                                  ? Icons.battery_5_bar_rounded
                                                                  : Icons.battery_alert_rounded,
                                                          size: 30,
                                                          color: batVolts > 75
                                                              ? Colors.greenAccent[400]
                                                              : Colors.amber,
                                                        ),
                                                        if (globals.showBatteryPercentage)
                                                          Text(
                                                            '$batVolts',
                                                            style: const TextStyle(
                                                              color: Colors.black,
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                      ],
                                                    );
                                                  }
                                                }
                                              }

                                              // Fallback battery icon
                                              return Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.battery_alert_rounded,
                                                    size: 30,
                                                    color: Colors.red,
                                                  ),
                                                  if (globals.showBatteryPercentage)
                                                    const Text(
                                                      '0',
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
                // Onboarding overlay - shown when no rooms are added
                if (_showOnboardingOverlay && !_onboardingDismissed)
                  _buildOnboardingOverlay(),
              ],
            ),
          );
        });
  }

  Future<String?> openRenameDialog() => showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Rename Door'),
            content: TextField(
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: 'Enter New Door Name'),
              controller: controller,
              inputFormatters: [
                LengthLimitingTextInputFormatter(6), // Limit to 6 characters
              ],
            ),
            actions: [
              TextButton(
                onPressed: submit,
                child: const Text('SUBMIT'),
              )
            ]),
      );
  void submit() {
    Navigator.of(context).pop(controller.text);
  }

  buildPageView() {
    return PageView(
      controller: pageController,
      onPageChanged: onPageChanged,
      children: [
        buildRoomsPage(),
        const NotificationsScreen(),
        const SettingsScreen(),
      ],
    );
  }

  onPageChanged(int page) {
    setState(() {
      currentIndex = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      body: Stack(
        children: [
          buildPageView(),
          const ShareRequestHandler(),
        ],
      ),
      bottomNavigationBar: buildBottomNavigationBar(),
    );
  }

  // Launch URL in browser
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch $url');
    }
  }

  // Build the onboarding overlay widget
  Widget _buildOnboardingOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _onboardingDismissed = true;
          _showOnboardingOverlay = false;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: SafeArea(
          child: Stack(
            children: [
              // Arrow and text pointing to + button (positioned at top right, horizontal)
              Positioned(
                top: 55.h,
                right: 50.w,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tap here to add your first door',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Horizontal arrow pointing right
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 40.sp,
                    ),
                  ],
                ),
              ),

              // Main content - centered help text
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Locksure logo
                      Image.asset(
                        'assets/images/logo.png',
                        width: 80.w,
                        height: 80.h,
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        'Welcome to Locksure!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Get started by adding your first door sensor',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16.sp,
                        ),
                      ),
                      SizedBox(height: 40.h),

                      // Setup guides section
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Haven't installed your door sensors?",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 16.h),

                            // Thumb Turn Setup Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _launchURL('https://locksure.co.uk/home-locksure-co-uk-the-door-security-game-changer-pl/locksure-door-thumb-lock-monitor-getting-started/');
                                },
                                icon: const Icon(Icons.touch_app, color: Colors.white),
                                label: const Text(
                                  'Thumb Turn Setup Guide',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),

                            // Key Turn Setup Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _launchURL('https://locksure.co.uk/home-locksure-co-uk-the-door-security-game-changer-pl/locksure-door-key-lock-monitor-getting-started/');
                                },
                                icon: const Icon(Icons.vpn_key, color: Colors.white),
                                label: const Text(
                                  'Key Turn Setup Guide',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 30.h),
                      Text(
                        'Tap anywhere to dismiss',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void listenForShareRequests() {
    FirebaseFirestore.instance
        .collection('shareRequests')
        .where('recipientEmail',
            isEqualTo: FirebaseAuth.instance.currentUser!.email)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          showShareRequestDialog(change.doc);
        }
      }
    });
  }

  void listenForRequestResponses() {
    FirebaseFirestore.instance
        .collection('shareRequests')
        .where('senderUid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final status = change.doc.data()!['status'];
          if (status == 'rejected') {
            showRejectionDialog(change.doc.data()!['recipientEmail']);
          }
        }
      }
    });
  }

  void showShareRequestDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Share Request'),
        content: Text(
            '${data['senderEmail']} wants to share "${data['roomName']}" with you.'),
        actions: [
          TextButton(
            onPressed: () => handleShareResponse(doc.id, 'rejected'),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () => handleShareResponse(doc.id, 'accepted'),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void showRejectionDialog(String recipientEmail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Request Rejected'),
        content: Text('$recipientEmail has declined your share request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> handleShareResponse(String requestId, String response) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('shareRequests')
          .doc(requestId)
          .get();

      final requestData = requestDoc.data()!;

      // Update request status
      await requestDoc.reference.update({'status': response});

      if (response == 'accepted') {
        // Add user to sharedWith array and store share timestamp
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(requestData['roomId'])
            .update({
          'sharedWith':
              FieldValue.arrayUnion([FirebaseAuth.instance.currentUser!.uid]),
          'sharedAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pop(context); // Close dialog
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

class GridElement {
  late bool isSelected;
  late String name;
  late IconData icon;
  GridElement(
      {required this.icon, required this.isSelected, required this.name});
}
