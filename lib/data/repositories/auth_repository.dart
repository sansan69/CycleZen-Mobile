import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cyclezen/domain/models/models.dart';

class AuthRepository {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();
  fb.User? get currentUser => _auth.currentUser;

  // ── Google Sign-In ──────────────────────────────────────

  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return _handleFirebaseUser(userCredential.user, 'google');
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_getFriendlyErrorMessage(e.code));
    } catch (e) {
      throw Exception('Sign in failed: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // ── Email / Password ───────────────────────────────────

  Future<User?> signUpWithEmail(String email, String password, String displayName) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.sendEmailVerification();
      return _handleFirebaseUser(userCredential.user, 'email',
          displayName: displayName);
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_getFriendlyErrorMessage(e.code));
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _handleFirebaseUser(userCredential.user, 'email');
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_getFriendlyErrorMessage(e.code));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Phone Auth ─────────────────────────────────────────

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(fb.PhoneAuthCredential) onCodeSent,
    required Function(fb.FirebaseAuthException) onError,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (fb.PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (fb.FirebaseAuthException e) => onError(e),
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(fb.PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: '', // placeholder — user enters code separately
        ));
      },
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  Future<User?> signInWithPhoneCredential(fb.PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      return _handleFirebaseUser(userCredential.user, 'phone');
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_getFriendlyErrorMessage(e.code));
    }
  }

  // ── Shared ─────────────────────────────────────────────

  Future<User?> _handleFirebaseUser(fb.User? fbUser, String provider,
      {String? displayName}) async {
    if (fbUser == null) return null;

    final userDoc = await _firestore.collection('users').doc(fbUser.uid).get();
    if (!userDoc.exists) {
      await _firestore.collection('users').doc(fbUser.uid).set({
        'email': fbUser.email,
        'phoneNumber': fbUser.phoneNumber,
        'displayName': displayName ?? fbUser.displayName,
        'photoUrl': fbUser.photoURL,
        'provider': provider,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Update last login provider
      await _firestore.collection('users').doc(fbUser.uid).update({
        'lastProvider': provider,
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    }

    final data = userDoc.data();
    return User(
      uid: fbUser.uid,
      email: fbUser.email,
      displayName: fbUser.displayName ?? data?['displayName'],
      photoUrl: fbUser.photoURL,
      phoneNumber: fbUser.phoneNumber ?? data?['phoneNumber'],
      weightKg: (data?['weightKg'] as num?)?.toDouble(),
      provider: provider,
    );
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> updateProfile({
    String? displayName,
    double? weightKg,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (weightKg != null) updates['weightKg'] = weightKg;
    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }

  String _getFriendlyErrorMessage(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'This email is already registered. Sign in instead.';
      case 'user-not-found':
        return 'No account found with this email. Sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Console.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return 'Sign in failed ($code). Please try again.';
    }
  }
}
