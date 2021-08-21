import 'package:firebase_auth/firebase_auth.dart';
import 'package:lockstate/services/firestore_service.dart';
import 'package:momentum/momentum.dart';

class AuthService extends MomentumService {
  final FirebaseAuth auth = FirebaseAuth.instance;

  login(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  logout() async {
    await auth.signOut();
  }

  signup(String email, String password, String username) async {
    print("signup email = " + email);
    print("signup password = " + password);
    print("signup username = " + username);
    UserCredential userCredential = await auth
        .createUserWithEmailAndPassword(email: email, password: password)
        .then((userCredential) {
      return FirestoreService()
          .createUserInFirestore(userCredential.user!.uid, email, username);
    });

    //     .whenComplete(() {
    // FirestoreService()
    //     .createUserInFirestore(auth.currentUser!.uid, email, username);
    // });
  }
}
