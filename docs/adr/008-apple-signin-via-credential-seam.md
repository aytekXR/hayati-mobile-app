# ADR-008: Sign in with Apple through a credential seam, not `signInWithProvider`

- **Status:** Accepted
- **Date:** 2026-07-09
- **Deciders:** Founder (session 005, M1.3)
- **Related:** ADR-002 (Firebase); ADR-006 (iOS-first); `architecture.md` §2; `implementation-plan.md` M1; `test-suite.md` (emulator-backed integration tests); `past-prompts.md` Session 003 (the Google credential seam this mirrors)

## Context

M1.3 adds Sign in with Apple to the auth data layer. `firebase_auth` 6.5.4 offers two mutually exclusive routes on iOS, and they differ in a way that decides whether the flow can be tested at all.

- **`signInWithProvider(AppleAuthProvider())`** — the plugin runs the entire native authorization flow internally and returns a `UserCredential`. Reading the resolved sources (`method_channel_firebase_auth.dart:444-468`), the method channel sends only an `InternalSignInProvider(providerId, scopes, customParameters)`; **no token and no `AuthCredential` is ever surfaced to Dart**.
- **`signInWithCredential(credential)`** — the caller obtains an Apple identity token itself (via the `sign_in_with_apple` package's native `ASAuthorization` flow), wraps it with `AppleAuthProvider.credentialWithIDToken(idToken, rawNonce, appleFullPersonName)`, and hands Firebase a credential. The credential is forwarded verbatim: `signInWithCredential` sends `credential.asMap()` over pigeon with **zero client-side token validation** (`method_channel_firebase_auth.dart:366-373`, `messages.pigeon.dart:1613-1623`).

That second fact is load-bearing. Because the plugin does not validate the token, the Firebase Auth emulator accepts an *unsigned* JSON `id_token` through `signInWithIdp` — the exact mechanism M1.1 already validated for Google and which was re-proved for `providerId=apple.com` over REST before any code was written this session. `signInWithProvider` has no seam to substitute, cannot run headlessly, and therefore cannot be exercised on the emulator or in a VM unit test.

The project's existing `GoogleAuthGateway` (`acquireCredential() → AuthCredential?`, `null` = user cancelled) is the shape that made the Google flow testable. Apple should not invent a second shape.

A secondary constraint: `SignInWithApple` is an all-static class, so it cannot be mock-injected the way `GoogleSignIn` can.

## Decision

1. **Adopt `sign_in_with_apple` 8.1.0 + `AppleAuthProvider.credentialWithIDToken` + `FirebaseAuth.signInWithCredential`**, behind a new `AppleAuthGateway.acquireCredential()` seam that mirrors `GoogleAuthGateway` exactly (returns `AuthCredential?`; `null` means the user backed out; every other failure is mapped into the `AuthException` taxonomy at the gateway boundary).
2. **Reject `signInWithProvider`** for this flow. It surfaces no credential, so it is neither fakeable in the VM nor drivable against the Auth emulator.
3. **Make the gateway VM-testable by injecting function seams**, not plugin mocks: a `GetAppleIdCredential` typedef defaulting to `SignInWithApple.getAppleIDCredential`, and a `String Function()` nonce generator defaulting to `generateNonce`.
4. **Honour the two-value nonce protocol.** `rawNonce = generator()`; `sha256(utf8.encode(rawNonce))` as hex is passed to `getAppleIDCredential(nonce:)` (Apple embeds it in the returned identity token); the **plain** `rawNonce` is passed to `credentialWithIDToken`, because Firebase requires `SHA-256(rawNonce) == the token's nonce claim`. A unit test asserts this relationship rather than trusting it.
5. **`AppleAuthGateway` exposes no `signOut`.** Apple has no client-side session to revoke; `signOut()` keeps clearing Google + Firebase only.

## Consequences

**Positive**

- The Apple flow is covered exactly like Google: fake-backed unit tests in the VM, plus an Auth-emulator integration round-trip that substitutes an `_EmulatorAppleAuthGateway` returning an unsigned `apple.com` credential. No Apple account, no device, and no Apple portal configuration is needed to prove the repository path.
- One gateway shape serves all three providers, so the repository, the state machine, and their tests stay uniform.
- Apple portal Service ID / key configuration is **not** required for the iOS-native or emulator paths (those are web/Android concerns, deferred with the rest of Android to M6.5). The only iOS build requirement is the `com.apple.developer.applesignin` entitlement, which is inert under CI's `flutter build ios --no-codesign` (entitlements are consumed at codesign time).

**Negative / accepted trade-offs**

- One more direct dependency (`sign_in_with_apple` 8.1.0, plus `crypto` promoted from transitive to direct for `sha256`). Verified SwiftPM-safe: the plugin ships `darwin/sign_in_with_apple/Package.swift`, so it does **not** reintroduce a Podfile — the hybrid that broke CI in Session 003.
- **Error-taxonomy asymmetry.** Apple's `AuthorizationErrorCode` has no transient/network member, so no Apple failure maps to `AuthNetworkException`; transient Apple failures land in `AuthUnknownException` and the UI's retry affordance relies on that copy. Google, by contrast, does map network errors.
- Apple sends the user's name and email **only on the first authorization**. The gateway forwards them via `AppleFullPersonName`, but whether Firebase persists them to `displayName` is native/backend behaviour that the emulator does not exercise — an explicit real-device verification item. The app must eventually persist the name itself rather than assume it can re-read it.
- The stopping condition recorded in the Session-005 resume prompt ("if `sign_in_with_apple` fights the emulator, fall back to the `OAuthProvider` flow") must **not** be read as a fallback to `signInWithProvider`: that route is strictly worse for testability. The emulator fallback is always `signInWithCredential` with a fake token through the gateway.

**Neutral**

- The emulator gateway builds its credential with `OAuthProvider('apple.com').credential(idToken: …)` and no `rawNonce` — an unsigned JSON token carries no nonce claim to match. Its `signInMethod` defaults to `'oauth'`; the emulator keys on `providerId`, so this is harmless, and `'apple.com'` can be pinned explicitly if that ever changes.
