import 'package:momentum/momentum.dart';

import 'index.dart';

class DataController extends MomentumController<DataModel> {
  @override
  DataModel init() {
    return DataModel(
      this,
      account: null,
    );
  }
}
