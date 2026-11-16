import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  bool get isFirebaseReady => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ---- estado ----
  Stream<User?> get authStateChanges =>
      isFirebaseReady ? _auth.userChanges() : Stream<User?>.value(null);
  User? get currentUser => isFirebaseReady ? _auth.currentUser : null;
  String? get uid => isFirebaseReady ? _auth.currentUser?.uid : null;

  Future<String> getOrCreateUid() async {
    if (!isFirebaseReady) return 'guest';
    try {
      final u = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
      return u!.uid;
    } catch (_) {
      return 'guest'; // fallback só para testes
    }
  }

  Future<void> signOut() async {
    if (!isFirebaseReady) return;
    await _auth.signOut();
  }

  // ---- LOGIN ----
  Future<UserCredential> signInEmailPassword(String email, String password) async {
    if (!isFirebaseReady) {
      throw StateError(
        'Firebase não configurado. Adicione google-services.json para usar o login.',
      );
    }
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureUserDoc(cred.user!);
    return cred;
  }

  static String friendlyError(Object error) {
    if (error is StateError) {
      return error.message;
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
          return 'E-mail ou senha incorretos.';
        case 'user-not-found':
          return 'Usuário não encontrado. Crie uma conta para continuar.';
        case 'wrong-password':
          return 'Senha incorreta.';
        case 'email-already-in-use':
          return 'Este e-mail já está em uso.';
        case 'weak-password':
          return 'A senha é muito fraca. Use pelo menos 6 caracteres.';
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'too-many-requests':
          return 'Muitas tentativas. Aguarde alguns instantes e tente novamente.';
        case 'network-request-failed':
          return 'Sem conexão com a internet. Verifique sua rede.';
        default:
          return error.message ?? 'Erro na autenticação (${error.code}).';
      }
    }
    return 'Erro inesperado: $error';
  }

  // ---- SIGNUP ----
  Future<UserCredential> signUpEmailPassword({
    required String email,
    required String password,
    String? name,
  }) async {
    if (!isFirebaseReady) {
      throw StateError(
        'Firebase não configurado. Adicione google-services.json para criar conta.',
      );
    }
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (name != null && name.trim().isNotEmpty) {
      await cred.user!.updateDisplayName(name.trim());
    } else {
      await cred.user!.updateDisplayName(email.split('@').first);
    }
    await _ensureUserDoc(cred.user!);
    return cred;
  }

  // ---- RESET PASSWORD ----
  Future<void> sendPasswordReset({required String email}) async {
    if (!isFirebaseReady) {
      throw StateError(
        'Firebase não configurado. Adicione google-services.json para redefinir a senha.',
      );
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ---- PROFILE ----
  Future<void> updateProfile({required String name}) async {
    if (!isFirebaseReady) return;
    final u = _auth.currentUser;
    if (u == null) return;
    await u.updateDisplayName(name);
    await _db.collection('users').doc(u.uid).set({
      'name': name,
      'email': u.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureUserDoc(User u) async {
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'name': u.displayName ?? '',
        'email': u.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
