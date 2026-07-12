import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// The credential length (ADR-018 Decision 1): a fixed 6-digit numeric PIN, the
/// iOS passcode convention. 10⁶ is the ceiling ANY app-level PIN offers; see the
/// honesty note below before "improving" anything here.
const int kPinLength = 6;

/// The salt width in bytes (128 bits), per-device, from [Random.secure].
const int _kSaltBytes = 16;

/// HASH HONESTY — read this before you "harden" it (ADR-018 Decision 2).
///
/// `pinHash = SHA-256(salt ‖ pin)`. There is deliberately **no iterated KDF**
/// (no PBKDF2/scrypt/argon2), and that is not an oversight:
///
/// * Against an attacker who has already extracted the Keychain record, a 10⁶
///   PIN space falls to any offline search regardless of iteration count. A KDF
///   here would be security theatre, and we do not claim otherwise.
/// * The hash exists so the raw PIN is never at rest ANYWHERE — defence against
///   casual disclosure: storage dumps, debug tooling, our own future code
///   touching the record.
/// * The REAL online control is attempt bounding (Decision 4 — the persisted
///   counter and escalating cooldown). The real at-rest control is the Keychain
///   itself.
///
/// So: adding a KDF would not change the threat model, and a future reader must
/// not believe it did. If the threat model ever DOES change (longer credential,
/// a passphrase), revisit this comment first — not the iteration count.

/// A fresh 128-bit salt from [Random.secure], base64-encoded. One per lock
/// record (regenerated on every enable).
String generateSalt() {
  final random = Random.secure();
  final bytes = List<int>.generate(
    _kSaltBytes,
    (_) => random.nextInt(256),
    growable: false,
  );
  return base64Encode(bytes);
}

/// `base64(SHA-256(base64Decode(salt) ‖ utf8(pin)))` — see the honesty note.
String hashPin({required String pin, required String salt}) {
  final digest = sha256.convert([
    ...base64Decode(salt),
    ...utf8.encode(pin),
  ]);
  return base64Encode(digest.bytes);
}

/// Compares two base64 digests without a data-dependent early exit.
///
/// The XOR-fold runs over the DECODED bytes for the full max-length of the two
/// inputs (missing bytes fold in as 0), so the loop's cost does not depend on
/// WHERE the first differing byte sits — a short-circuiting `==` leaks a
/// prefix-length oracle. The length equality is folded into the verdict at the
/// end rather than short-circuiting at the top. Undecodable input (garbage in a
/// tampered record) compares as unequal rather than throwing.
bool constantTimeEquals(String a, String b) {
  final left = _tryDecode(a);
  final right = _tryDecode(b);
  if (left == null || right == null) return false;

  final length = max(left.length, right.length);
  var diff = 0;
  for (var i = 0; i < length; i++) {
    final x = i < left.length ? left[i] : 0;
    final y = i < right.length ? right[i] : 0;
    diff |= x ^ y;
  }
  return diff == 0 && left.length == right.length;
}

List<int>? _tryDecode(String value) {
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}
