import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class CloudSnapshot {
  final Map<String, dynamic>? state;
  final int revision;
  const CloudSnapshot(this.state, this.revision);
}

/// One versioned backup per owner. Transactions reject stale-device writes.
class GoogleServices {
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static bool get configured => projectId.isNotEmpty;

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseStorage? storage;
  GoogleServices(this.auth, this.firestore, {this.storage});
  static const maxPhotoBytes = 6 * 1024 * 1024;

  static Future<GoogleServices?> initialize() async {
    if (!configured) return null;
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const bucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    final appId = kIsWeb ? webAppId : androidAppId;
    if (apiKey.isEmpty ||
        senderId.isEmpty ||
        appId.isEmpty ||
        (!kIsWeb && webClientId.isEmpty)) {
      throw StateError(
        'Konfigurasi Google belum lengkap. Periksa config/google.local.json.',
      );
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
          storageBucket: bucket.isEmpty ? null : bucket,
          authDomain:
              const String.fromEnvironment('FIREBASE_AUTH_DOMAIN').isEmpty
              ? '$projectId.firebaseapp.com'
              : const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        ),
      );
    }
    final storage = bucket.isEmpty
        ? null
        : FirebaseStorage.instanceFor(bucket: 'gs://$bucket');
    if (storage != null) {
      storage.setMaxUploadRetryTime(const Duration(seconds: 20));
      storage.setMaxDownloadRetryTime(const Duration(seconds: 20));
    }
    final services = GoogleServices(
      FirebaseAuth.instance,
      FirebaseFirestore.instance,
      storage: storage,
    );
    await services.auth.authStateChanges().first.timeout(
      const Duration(seconds: 15),
    );
    return services;
  }

  bool _googleInitialized = false;
  Future<User> signIn() async {
    final UserCredential result;
    if (kIsWeb) {
      result = await auth.signInWithPopup(GoogleAuthProvider());
    } else {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(serverClientId: webClientId);
        _googleInitialized = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw StateError('Google tidak memberikan token masuk.');
      }
      result = await auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
    }
    return result.user!;
  }

  Future<void> signOut() async {
    await auth.signOut();
    if (!kIsWeb && _googleInitialized) await GoogleSignIn.instance.signOut();
  }

  Future<String?> idToken() async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Masuk dengan Google terlebih dahulu.');
    return user.getIdToken();
  }

  DocumentReference<Map<String, dynamic>> _ref(String uid) => firestore
      .collection('owners')
      .doc(uid)
      .collection('backups')
      .doc('current');

  Reference _photoRef(String uid, String documentId) {
    if (auth.currentUser?.uid != uid) {
      throw StateError('Sesi Google berubah. Masuk kembali.');
    }
    if (storage == null) {
      throw StateError('Penyimpanan foto Google belum dihubungkan.');
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(documentId)) {
      throw StateError('ID dokumen tidak valid.');
    }
    return storage!.ref('owners/$uid/documents/$documentId/original');
  }

  Future<void> uploadPhoto(
    String uid,
    String documentId,
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty || bytes.length > maxPhotoBytes) {
      throw StateError('Ukuran foto harus antara 1 byte dan 6 MB.');
    }
    final mime = photoMime(bytes);
    final task = _photoRef(
      uid,
      documentId,
    ).putData(bytes, SettableMetadata(contentType: mime));
    try {
      await task.timeout(const Duration(seconds: 35));
    } on TimeoutException {
      await task.cancel();
      throw StateError(
        'Unggah foto terlalu lama. Periksa koneksi lalu proses ulang.',
      );
    }
  }

  Future<Uint8List> downloadPhoto(String uid, String documentId) async {
    final bytes = await _photoRef(
      uid,
      documentId,
    ).getData(maxPhotoBytes).timeout(const Duration(seconds: 30));
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Foto asli tidak ditemukan di cloud.');
    }
    return bytes;
  }

  static String photoMime(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) {
      return 'image/jpeg';
    }
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4e &&
        b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length >= 12 &&
        ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    if (b.length >= 12 &&
        ascii.decode(b.sublist(4, 8), allowInvalid: true) == 'ftyp' &&
        [
          'heic',
          'heix',
          'hevc',
          'hevx',
          'mif1',
        ].contains(ascii.decode(b.sublist(8, 12), allowInvalid: true))) {
      return 'image/heic';
    }
    throw StateError(
      'Format foto belum didukung. Gunakan JPG, PNG, WebP, atau HEIC.',
    );
  }

  Future<CloudSnapshot> read(String uid) async {
    final doc = await _ref(uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    final data = doc.data();
    if (data == null) return const CloudSnapshot(null, 0);
    return CloudSnapshot(
      jsonDecode(data['state'] as String) as Map<String, dynamic>,
      data['revision'] as int,
    );
  }

  Future<int> write(
    String uid,
    Map<String, dynamic> state,
    int revision,
  ) async {
    final encoded = jsonEncode(state);
    if (utf8.encode(encoded).length > 800000) {
      throw StateError(
        'Cadangan melebihi batas 800 KB. Data tetap tersimpan di perangkat.',
      );
    }
    return firestore.runTransaction((transaction) async {
      final ref = _ref(uid);
      final doc = await transaction.get(ref);
      final current = doc.data()?['revision'] as int? ?? 0;
      if (current != revision) {
        throw StateError(
          'Data cloud berubah di perangkat lain. Data lokal tetap aman; jangan menimpa cadangan.',
        );
      }
      transaction.set(ref, {
        'state': encoded,
        'revision': revision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return revision + 1;
    });
  }
}
