import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/data/repositories/auth_repository.dart';

// ── Events ──────────────────────────────────────────────

sealed class AuthEvent {
  const AuthEvent();
}
class AuthEventAppStarted extends AuthEvent {
  const AuthEventAppStarted();
}
class AuthEventSignInWithGoogle extends AuthEvent {
  const AuthEventSignInWithGoogle();
}
class AuthEventSignUpWithEmail extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  const AuthEventSignUpWithEmail({
    required this.email,
    required this.password,
    required this.displayName,
  });
}
class AuthEventSignInWithEmail extends AuthEvent {
  final String email;
  final String password;
  const AuthEventSignInWithEmail({
    required this.email,
    required this.password,
  });
}
class AuthEventResetPassword extends AuthEvent {
  final String email;
  const AuthEventResetPassword({required this.email});
}
class AuthEventVerifyPhoneCode extends AuthEvent {
  final String verificationId;
  final String smsCode;
  const AuthEventVerifyPhoneCode({
    required this.verificationId,
    required this.smsCode,
  });
}
class AuthEventSignOut extends AuthEvent {
  const AuthEventSignOut();
}
class AuthEventUpdateProfile extends AuthEvent {
  final String? displayName;
  final double? weightKg;
  const AuthEventUpdateProfile({this.displayName, this.weightKg});
}

// ── States ──────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}
class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}
class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}
class AuthStateAuthenticated extends AuthState {
  final User user;
  const AuthStateAuthenticated(this.user);
}
class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}
class AuthStateError extends AuthState {
  final String message;
  final String? details;
  const AuthStateError(this.message, {this.details});
}
class AuthStatePasswordResetSent extends AuthState {
  const AuthStatePasswordResetSent();
}

// ── BLoC ────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthStateInitial()) {
    on<AuthEventAppStarted>(_onAppStarted);
    on<AuthEventSignInWithGoogle>(_onSignInWithGoogle);
    on<AuthEventSignUpWithEmail>(_onSignUpWithEmail);
    on<AuthEventSignInWithEmail>(_onSignInWithEmail);
    on<AuthEventResetPassword>(_onResetPassword);
    on<AuthEventVerifyPhoneCode>(_onVerifyPhoneCode);
    on<AuthEventSignOut>(_onSignOut);
    on<AuthEventUpdateProfile>(_onUpdateProfile);
  }

  Future<void> _onAppStarted(
    AuthEventAppStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateLoading());
    final user = _authRepository.currentUser;
    if (user != null) {
      emit(AuthStateAuthenticated(_fbToAppUser(user)));
    } else {
      emit(const AuthStateUnauthenticated());
    }
  }

  Future<void> _onSignInWithGoogle(
    AuthEventSignInWithGoogle event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateLoading());
    try {
      final user = await _authRepository.signInWithGoogle();
      if (user != null) {
        emit(AuthStateAuthenticated(user));
      } else {
        emit(const AuthStateUnauthenticated());
      }
    } catch (e) {
      emit(_errorState(e));
    }
  }

  Future<void> _onSignUpWithEmail(
    AuthEventSignUpWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateLoading());
    try {
      final user = await _authRepository.signUpWithEmail(
        event.email,
        event.password,
        event.displayName,
      );
      if (user != null) {
        emit(AuthStateAuthenticated(user));
      } else {
        emit(const AuthStateUnauthenticated());
      }
    } catch (e) {
      emit(_errorState(e));
    }
  }

  Future<void> _onSignInWithEmail(
    AuthEventSignInWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateLoading());
    try {
      final user = await _authRepository.signInWithEmail(
        event.email,
        event.password,
      );
      if (user != null) {
        emit(AuthStateAuthenticated(user));
      } else {
        emit(const AuthStateUnauthenticated());
      }
    } catch (e) {
      emit(_errorState(e));
    }
  }

  Future<void> _onResetPassword(
    AuthEventResetPassword event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateLoading());
    try {
      await _authRepository.sendPasswordResetEmail(event.email);
      emit(const AuthStatePasswordResetSent());
    } catch (e) {
      emit(_errorState(e));
    }
  }

  Future<void> _onVerifyPhoneCode(
    AuthEventVerifyPhoneCode event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthStateLoading());
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
      );
      final user = await _authRepository.signInWithPhoneCredential(credential);
      if (user != null) {
        emit(AuthStateAuthenticated(user));
      } else {
        emit(const AuthStateUnauthenticated());
      }
    } catch (e) {
      emit(_errorState(e));
    }
  }

  Future<void> _onSignOut(
    AuthEventSignOut event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    emit(const AuthStateUnauthenticated());
  }

  Future<void> _onUpdateProfile(
    AuthEventUpdateProfile event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.updateProfile(
      displayName: event.displayName,
      weightKg: event.weightKg,
    );
    final fbUser = _authRepository.currentUser;
    if (fbUser != null) {
      emit(AuthStateAuthenticated(_fbToAppUser(fbUser,
          displayName: event.displayName, weightKg: event.weightKg)));
    }
  }

  // ── Helpers ───────────────────────────────────────────

  User _fbToAppUser(fb.User fbUser, {String? displayName, double? weightKg}) {
    return User(
      uid: fbUser.uid,
      email: fbUser.email,
      displayName: displayName ?? fbUser.displayName,
      photoUrl: fbUser.photoURL,
      phoneNumber: fbUser.phoneNumber,
      weightKg: weightKg,
      provider: fbUser.providerData.isNotEmpty
          ? fbUser.providerData.first.providerId
          : 'email',
    );
  }

  AuthStateError _errorState(Object e) {
    final msg = e.toString().replaceAll('Exception: ', '');
    final details = (msg.contains('PlatformException') ||
            msg.contains('sign_in_failed') ||
            msg.contains('invalid-credential'))
        ? '⚠️ Check that the auth provider is enabled in Firebase Console.\n'
          'Also verify SHA-1 fingerprint is registered:\n'
          '3B:CA:32:E0:47:79:0B:FD:E7:90:EC:26:2F:80:A4:90:07:4F:BD:B2'
        : null;
    return AuthStateError(msg, details: details);
  }
}
