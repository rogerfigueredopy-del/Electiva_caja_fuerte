import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  static final CryptoService instance = CryptoService._();
  CryptoService._();

  final _aesGcm = AesGcm.with256bits();
  final _random = Random.secure();

  Future<Uint8List> randomBytes(int length) async {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Encrypts [data] with a randomly generated DEK (data encryption key).
  /// The DEK is wrapped with the provided KEK using AES-GCM as well.
  /// Returns a tuple-like map with:
  /// - cipher: encrypted content bytes
  /// - fileIv: IV used for file encryption
  /// - dekWrapped: DEK encrypted with KEK
  /// - dekWrapIv: IV used for wrapping the DEK
  Future<Map<String, Uint8List>> encryptWithWrappedKey({
    required Uint8List data,
    required Uint8List kek,
  }) async {
    // Generate DEK
    final dek = await randomBytes(32);
    final fileIv = await randomBytes(12);
    final dekWrapIv = await randomBytes(12);

    // Encrypt file content with DEK
    final secretDek = SecretKey(dek);
    final secretBox = await _aesGcm.encrypt(
      data,
      secretKey: secretDek,
      nonce: fileIv,
    );

    // Wrap DEK with KEK
    final secretKek = SecretKey(kek);
    final wrapped = await _aesGcm.encrypt(
      dek,
      secretKey: secretKek,
      nonce: dekWrapIv,
    );

    return {
      'cipher': Uint8List.fromList(secretBox.cipherText + secretBox.mac.bytes),
      'fileIv': fileIv,
      'dekWrapped': Uint8List.fromList(wrapped.cipherText + wrapped.mac.bytes),
      'dekWrapIv': dekWrapIv,
    };
  }

  /// Decrypts content: unwrap DEK with KEK, then decrypt file.
  Future<Uint8List> decryptWithWrappedKey({
    required Uint8List cipherWithTag,
    required Uint8List fileIv,
    required Uint8List dekWrappedWithTag,
    required Uint8List dekWrapIv,
    required Uint8List kek,
  }) async {
    // Unwrap DEK
    final macDek = Mac(dekWrappedWithTag.sublist(dekWrappedWithTag.length - 16));
    final wrappedCipher = dekWrappedWithTag.sublist(0, dekWrappedWithTag.length - 16);
    final secretKek = SecretKey(kek);
    final wrapped = SecretBox(wrappedCipher, nonce: dekWrapIv, mac: macDek);
    final dek = await _aesGcm.decrypt(
      wrapped,
      secretKey: secretKek,
    );

    // Decrypt file
    final macFile = Mac(cipherWithTag.sublist(cipherWithTag.length - 16));
    final contentCipher = cipherWithTag.sublist(0, cipherWithTag.length - 16);
    final secretDek = SecretKey(Uint8List.fromList(dek));
    final box = SecretBox(contentCipher, nonce: fileIv, mac: macFile);
    final clear = await _aesGcm.decrypt(box, secretKey: secretDek);
    return Uint8List.fromList(clear);
  }

  static String b64(Uint8List data) => base64Encode(data);
  static Uint8List b64d(String s) => Uint8List.fromList(base64Decode(s));
}
