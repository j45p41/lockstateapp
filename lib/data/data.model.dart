import 'package:lockstate/model/account.dart';
import 'package:momentum/momentum.dart';

import 'index.dart';

class DataModel extends MomentumModel<DataController> {
  DataModel(DataController controller, {this.account}) : super(controller);

  final Account? account;

  @override
  void update({Account? account}) {
    DataModel(controller, account: account ?? this.account).updateMomentum();
  }
}
