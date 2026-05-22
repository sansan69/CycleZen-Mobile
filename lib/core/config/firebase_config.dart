import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration for CycleZen Android app.
/// Values sourced from google-services.json (project: cyclezen-qdvh0)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyCG4xg_lQ6DNTDayEnKAogPsHTqgxSp1fM',
      appId: '1:834716576876:android:6e2777dada5c71c4867c49',
      messagingSenderId: '834716576876',
      projectId: 'cyclezen-qdvh0',
      authDomain: 'cyclezen-qdvh0.firebaseapp.com',
      storageBucket: 'cyclezen-qdvh0.firebasestorage.app',
    );
  }
}
