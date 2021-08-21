import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:momentum/momentum.dart';

import 'index.dart';

class AuthenticationModel extends MomentumModel<AuthenticationController> {
  AuthenticationModel(AuthenticationController controller,
      {this.authSubscription, this.userSnapshot})
      : super(controller);
  final StreamSubscription<User?>? authSubscription;
  final User? userSnapshot;

  @override
  void update(
      {StreamSubscription<User?>? authSubscription, User? userSnapshot}) {
    AuthenticationModel(
      controller,
      authSubscription: authSubscription ?? this.authSubscription,
      userSnapshot: userSnapshot ?? this.userSnapshot,
    ).updateMomentum();
  }
}
