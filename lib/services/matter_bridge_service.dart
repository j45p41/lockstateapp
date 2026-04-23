import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lockstate/model/matter_state_event.dart';
import 'package:lockstate/services/matter_home_service.dart';

/// Bridges Matter device state changes from HomeKit/Google Home to Firebase.
///
/// When the app receives a lock/door state change via the native platform,
/// this service writes it to the same Firestore collections the Hub uses
/// (devices, notifications, rooms) so the existing UI works unchanged.
///
/// History is only recorded while the app is active — this is an accepted
/// limitation of the Matter/HomeKit/Google Home architecture.
class MatterBridgeService {
  static final MatterBridgeService _instance = MatterBridgeService._internal();
  factory MatterBridgeService() => _instance;
  MatterBridgeService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _matterHome = MatterHomeService();
  StreamSubscription? _stateSubscription;
  bool _isRunning = false;

  /// Start listening to Matter state events and bridging them to Firebase.
  /// Call after user login, when Matter devices exist.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _stateSubscription = _matterHome.stateEvents.listen(
      _onStateEvent,
      onError: (e) => print('[MatterBridge] Stream error: $e'),
    );

    print('[MatterBridge] Started — bridging Matter events to Firebase');
  }

  /// Stop listening. Call on logout or app dispose.
  void stop() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
    _isRunning = false;
    print('[MatterBridge] Stopped');
  }

  /// Subscribe to all Matter devices the user has in Firebase.
  Future<void> subscribeToAllDevices() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await _firestore
        .collection('devices')
        .where('userId', isEqualTo: uid)
        .where('connectionType', isEqualTo: 'MATTER')
        .get();

    for (var doc in snap.docs) {
      final matterUniqueId = doc.data()['matterUniqueId'] as String?;
      if (matterUniqueId != null) {
        await _matterHome.subscribeToDevice(matterUniqueId);
        print('[MatterBridge] Subscribed to ${doc.id}');
      }
    }
  }

  /// Compute the display state (1=Locked, 2=Unlocked, 3=Open, 4=Closed)
  /// from separate lock + door states. Lock state always takes priority
  /// because the firmware mirrors lock→door (no physical door sensor).
  static int _displayStateFromLockAndDoor(int lockState, int doorState) {
    if (lockState == 1) return 1;           // Locked
    if (lockState == 2) return 2;           // Unlocked
    if (doorState == 3) return 3;           // Open (standalone door sensor)
    if (doorState == 4) return 4;           // Closed
    return 0;                               // Unknown
  }

  /// Handle a state change event from the native platform.
  Future<void> _onStateEvent(MatterStateEvent event) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final deviceId = event.firebaseDeviceId;
    final timestamp = event.timestamp.toUtc().toIso8601String();

    try {
      // 1. Read device doc to get roomId and metadata + previous lock/door states
      final deviceDoc =
          await _firestore.collection('devices').doc(deviceId).get();
      if (!deviceDoc.exists) {
        print('[MatterBridge] Device doc not found: $deviceId');
        return;
      }
      final deviceData = deviceDoc.data()!;
      final roomId = deviceData['roomId'] as String? ?? '';
      final deviceName = deviceData['deviceName'] as String? ?? '';
      final isIndoor = deviceData['isIndoor'] as bool? ?? false;

      // Incoming event only contains one of lock or door. Merge with what's
      // already stored so display state reflects BOTH.
      final existingLock = (deviceData['matterLockState'] as num?)?.toInt() ?? 0;
      final existingDoor = (deviceData['matterDoorState'] as num?)?.toInt() ?? 0;

      int newLock = existingLock;
      int newDoor = existingDoor;
      if (event.lockState == 1 || event.lockState == 2) {
        newLock = event.lockState;
      }
      if (event.doorState == 3 || event.doorState == 4) {
        newDoor = event.doorState!;
      }

      final state = _displayStateFromLockAndDoor(newLock, newDoor);
      final batteryPct = event.batteryPercent;
      final fwVersion = event.firmwareVersion;
      final currentState = deviceData['state'] as int? ?? 0;
      final storedBattery = (deviceData['batteryPercent'] as num?)?.toInt();
      final storedFw = deviceData['firmwareVersion'] as String?;

      final stateChanged = !(currentState == state && state != 0);
      final batteryChanged = batteryPct != null && storedBattery != batteryPct;
      final fwChanged = fwVersion != null && fwVersion.isNotEmpty && storedFw != fwVersion;

      print('[MatterBridge] State event: $deviceId lock=$newLock door=$newDoor bat=$batteryPct fw=$fwVersion → display=$state (stateChanged=$stateChanged, batteryChanged=$batteryChanged, fwChanged=$fwChanged)');

      // Skip entirely if nothing changed.
      if (!stateChanged && !batteryChanged && !fwChanged) {
        print('[MatterBridge] Nothing changed, skipping');
        return;
      }

      // 2. Build device-doc update. Always include battery/fw when present so
      // battery-only or firmware-only events still populate the tile.
      final deviceUpdate = <String, dynamic>{};
      if (stateChanged) {
        deviceUpdate['state'] = state;
        deviceUpdate['matterLockState'] = newLock;
        deviceUpdate['matterDoorState'] = newDoor;
        deviceUpdate['last_update_recieved_at'] = timestamp;
      }
      if (batteryPct != null) {
        deviceUpdate['batteryPercent'] = batteryPct;
      }
      if (fwVersion != null && fwVersion.isNotEmpty) {
        deviceUpdate['firmwareVersion'] = fwVersion;
      }
      await _firestore.collection('devices').doc(deviceId).update(deviceUpdate);

      // 3. Dual-write to user's device subcollection
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .update(deviceUpdate);

      // Room state + notification document only when real lock/door state
      // changed — battery-only / firmware-only updates shouldn't create
      // notification records.
      if (!stateChanged) {
        print('[MatterBridge] Metadata-only update: $deviceId bat=$batteryPct fw=$fwVersion (no notification)');
        return;
      }

      // 4. Update room state
      if (roomId.isNotEmpty) {
        await _firestore.collection('rooms').doc(roomId).update({
          'state': state,
        });
      }

      // 5. Write notification document (same format as Hub)
      final notifId = '$deviceId${event.timestamp.millisecondsSinceEpoch}';
      await _firestore.collection('notifications').doc(notifId).set({
        'deviceId': deviceId,
        'deviceName': deviceName,
        'userId': uid,
        'roomId': roomId,
        'isIndoor': isIndoor,
        'state': state,
        'volts': -1,
        'count': -1,
        'connectionType': 'MATTER',
        'batteryPercent': batteryPct ?? -1,
        'received_at': timestamp,
        'last_update_received_at': timestamp,
        'message': {
          'received_at': timestamp,
          'uplink_message': {
            'received_at': timestamp,
            'decoded_payload': {
              'lockState': state,
              'batVolts': -1,
              'lockCount': -1,
              'batteryPercent': batteryPct ?? -1,
            },
          },
        },
      });

      print('[MatterBridge] Firebase updated: $deviceId state=$state');
    } catch (e) {
      print('[MatterBridge] Error updating Firebase: $e');
    }
  }
}
