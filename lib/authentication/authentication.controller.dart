import 'package:momentum/momentum.dart';

import 'index.dart';

class AuthenticationController extends MomentumController<AuthenticationModel> {
  @override
  AuthenticationModel init() {
    return AuthenticationModel(
      this,
      // TODO: specify initial values here...
    );
  }
}
