import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lockstate/model/account.dart';
import 'package:lockstate/services/auth_service.dart';

import 'package:lockstate/services/firestore_service.dart';
import 'package:momentum/momentum.dart';

import 'index.dart';

class DataController extends MomentumController<DataModel> {
  @override
  DataModel init() {
    return DataModel(
      this,
      account: null,
      devicesSnapshot: null,
      devicesSubscription: null,
    );
  }

  getAccountFromFirestore() async {
    final firestoreService = service<FirestoreService>();
    Account account = firestoreService.getCurrentAccount();
    print("Data controller getAccount " + account.email.toString());
    model.update(account: account);
  }

  addDevice(String deviceId, String userId, String deviceName, bool isIndoor,String roomId) {
    print("Data controller addDevice");
    final firestoreService = service<FirestoreService>();
    firestoreService.addDevice(deviceId, userId, deviceName, isIndoor,roomId);
  }

  addRoom(String userId, String roomName) {
    final firestoreService = service<FirestoreService>();
    firestoreService.addRoom(userId, roomName);
  }
  // @override
  // void bootstrap() {
  //   print("Data controller bootStrap");
  //   final firestoreService = service<FirestoreService>();
  //   final authService = service<AuthService>();
  //   if (authService.auth.currentUser != null) {
  //     Account account = firestoreService.getCurrentAccount();
  //     print("Data controller bootstrap " + account.email.toString());
  //     model.update(account: account);

  //     // ignore: cancel_subscriptions
  //     final devicesSubscription = FirebaseFirestore.instance
  //         .collection('devices')
  //         .where("userId", isEqualTo: account.uid)
  //         .snapshots()
  //         .listen((querySnapshot) {
  //       model.update(devicesSnapshot: querySnapshot);
  //     });

  //     model.update(devicesSubscription: devicesSubscription);
  //   }
  //   super.bootstrap();
  // }
}
