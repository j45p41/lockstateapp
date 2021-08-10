import 'package:firebase/firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lockstate/services/firestore_service.dart';
import 'package:momentum/momentum.dart';

class AuthService extends MomentumService {
  final FirebaseAuth auth = FirebaseAuth.instance;

  Stream<User?> get authState => auth.userChanges();
  login(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  signup(String email, String password, String username) async {
    await auth
        .createUserWithEmailAndPassword(email: email, password: password)
        .whenComplete(() {
      FirestoreService()
          .createUserInFirestore(auth.currentUser!.uid, email, username);
    });
  }
}
