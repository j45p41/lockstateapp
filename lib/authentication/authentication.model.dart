import 'package:momentum/momentum.dart';

import 'index.dart';

class AuthenticationModel extends MomentumModel<AuthenticationController> {
  AuthenticationModel(AuthenticationController controller) : super(controller);

  // TODO: add your final properties here...

  @override
  void update() {
    AuthenticationModel(
      controller,
    ).updateMomentum();
  }
}
