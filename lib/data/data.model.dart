import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lockstate/model/account.dart';
import 'package:momentum/momentum.dart';
import 'index.dart';

class DataModel extends MomentumModel<DataController> {
  DataModel(DataController controller,
      {this.account, this.devicesSnapshot, this.devicesSubscription})
      : super(controller);

  final Account? account;
  final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      devicesSubscription;
  final QuerySnapshot<Map<String, dynamic>>? devicesSnapshot;
  @override
  void update(
      {Account? account,
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
          devicesSubscription,
      QuerySnapshot<Map<String, dynamic>>? devicesSnapshot}) {
    DataModel(
      controller,
      account: account ?? this.account,
      devicesSubscription: devicesSubscription ?? this.devicesSubscription,
      devicesSnapshot: devicesSnapshot ?? this.devicesSnapshot,
    ).updateMomentum();
  }
}
