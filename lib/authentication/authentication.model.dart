import 'package:momentum/momentum.dart';

import 'index.dart';

class AuthenticationModel extends MomentumModel<AuthenticationController> {
  AuthenticationModel(AuthenticationController controller) : super(controller);

  @override
  void update() {
    AuthenticationModel(
      controller,
    ).updateMomentum();
  }
}
