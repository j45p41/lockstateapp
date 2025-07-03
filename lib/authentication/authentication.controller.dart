import 'package:firebase_auth/firebase_auth.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/services/auth_service.dart';
import 'package:momentum/momentum.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;

import 'index.dart';

class AuthenticationController extends MomentumController<AuthenticationModel> {
  @override
  AuthenticationModel init() {
    return AuthenticationModel(
      this,
      authSubscription: null,
      userSnapshot: null,
    );
  }

  login(String email, String password) {
    var authService = service<AuthService>();
    authService.login(email, password);
    final dataController = controller<DataController>();
    dataController.getAccountFromFirestore();
    dataController.bootstrap();
    model.update();
  }

  signup(
    String email,
    String password,
    String username,
  ) {
    var authService = service<AuthService>();
    var isCreated = authService.signup(email, password, username);
    model.update();

    return isCreated;
  }

  logout() {
    var authService = service<AuthService>();
    authService.logout();
    model.update();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    globals.emailSucess = false;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: globals.email);

      print('SUCESS CASE');

      globals.emailSucess = true;

      // Handle success, e.g., show a success message
    } on FirebaseAuthException catch (e) {
      // Handle errors, e.g., show an error message
      print(e.message);

      if (!globals.emailSucess) {
        globals.e = e;
      }
    }
  }

  @override
  void bootstrap() {
    // ignore: cancel_subscriptions
    final authSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      model.update(userSnapshot: user);
    });

    model.update(authSubscription: authSubscription);
    super.bootstrap();
  }
}
