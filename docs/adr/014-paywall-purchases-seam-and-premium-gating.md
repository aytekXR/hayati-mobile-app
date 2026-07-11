# ADR-014: Paywall, purchases seam, and premium gating

- **Status:** Accepted
- **Date:** 2026-07-11
- **Deciders:** Session 016 (per `docs/resume-prompt.md` M4.2; design adversarially reviewed before implementation, the ADR-013 discipline)
- **Related:** [ADR-003](003-revenuecat-for-entitlements.md) (RevenueCat pre-decided); [ADR-013](013-revenuecat-webhook-entitlement-mirror.md) (server truth: `subscriptions/{coupleId}` mirror; `isPremium` = entitled AND unexpired; `entitled` never sufficient alone; `Purchases.logIn(firebaseUid)` load-bearing for identity resolution); `docs/architecture.md` §2 (seam/bootstrap conventions), §4 (entitlements flow); `docs/prd.md` F4; `docs/test-suite.md` §1

## Context

M4.1 built the server truth and the app's decision point (`isPremiumProvider(coupleId:)` — zero UI consumers by design). M4.2 builds the surface that sells and the flips that gate:

1. a **`PurchasesRepository` seam** over `purchases_flutter` (the SDK drives platform channels — untestable in the `flutter test` VM, the M2.2 `cloud_functions` precedent — so ALL tests run against a fake; the real adapter is exercised on-device at M4.3),
2. the **paywall screen** (PRD F4: annual-first, trial messaging, one-purchase-covers-both, store-localized prices — never hardcoded),
3. the **premium gate**: a reusable widget every later premium feature (coach at M5) mounts on, flipped purely by `isPremium`, with the pack-selection surface as the first gated target — while the free tier (daily question + streak + solo) stays untouched by assertion.

There is **no RevenueCat account yet** (operator item 0) — the live-sandbox half (real API key, products, sandbox purchase) moves to M4.3, which owns sandbox accept lines anyway. Everything below is buildable and provable against mocked offerings.

SDK facts this design rests on (verified against `purchases_flutter` **10.4.1**, published 2026-07-08, pinned `^10.4.1`; Dart ≥3.4/Flutter ≥3.22 floors satisfied):

- 10.0.0 broke the 9.x pattern: purchase methods return **`PurchaseResult`** (not `CustomerInfo`); `PurchaseParams.package(pkg)` + `Purchases.purchase(params)` is the current API; freezed models replaced by manually-parsed classes; `usesStoreKit2IfAvailable` → `storeKitVersion`.
- **Every model class has a public `const` constructor** (`Offerings`, `Offering`, `Package`, `StoreProduct`, `IntroductoryPrice`, `CustomerInfo`, `EntitlementInfo(s)` — verified in the 10.4.1 source), so a fake can mint *real* SDK objects and the live wiring lands without reshaping.
- Trial detection: iOS = `StoreProduct.introductoryPrice` (`IntroductoryPrice{price, priceString, periodUnit, periodNumberOfUnits, cycles}`; **a free trial is `price == 0`** — a non-zero intro price is a discount, never trial copy); Android/cross-store = `SubscriptionOption.freePhase != null` (mapped for M6.5 completeness, iOS-first now).
- Errors surface as `PlatformException` → `PurchasesErrorHelper.getErrorCode(e)` → `PurchasesErrorCode` (pure, VM-testable); user cancel = `purchaseCancelledError`.
- `Purchases.restorePurchases() → Future<CustomerInfo>`; `Purchases.logIn(String) → Future<LogInResult>`.

## Decision 1 — Seam shape: the repository speaks the SDK's model types

`PurchasesRepository` (in `features/entitlements/domain/`) exposes `purchases_flutter`'s **model** types directly:

```dart
abstract interface class PurchasesRepository {
  Future<void> logIn(String appUserId);
  Future<void> logOut();
  Future<Offerings> fetchOfferings();
  Future<CustomerInfo> purchase(Package package);   // adapter builds PurchaseParams.package(...)
  Future<CustomerInfo> restore();
}
```

- **Why SDK types, not house mirrors:** the resume-prompt's fidelity requirement — the fake must be built from the SDK's real types so M4.3's live wiring is a bootstrap override, not a reshape. The model classes are pure-Dart data (`const` ctors, no platform channels); only the `Purchases.*` statics touch channels, and those live exclusively inside the real adapter. The domain-purity rule (architecture §2) is read as "no Flutter/platform imports": a pure-Dart data dependency is acceptable where mirroring it would create drift risk against a moving SDK. The *paywall* never renders SDK types raw — it renders the Decision 3 display model, so the SDK surface stays contained to the seam + one pure derivation.
- **Provider:** `purchasesRepositoryProvider`, `@Riverpod(keepAlive: true)` throw-until-overridden (house pattern), overridden in both entrypoints with the real adapter and per-test with the fake.
- **Real adapter** `RcPurchasesRepository` (`data/`): thin forwarding onto `Purchases.*` statics; every call wrapped by the taxonomy mapper (Decision 2). Deliberately not unit-tested (nothing but forwarding; the statics are channel-backed) — its correctness is the M4.3 on-device smoke, the M2.2 precedent.
- **Purchase return value:** the seam returns `PurchaseResult.customerInfo` (`CustomerInfo`) — a **hint, never truth** (ADR-013): no UI state flips entitled from it. `StoreTransaction` is dropped at the seam; nothing consumes it before M4.3.
- **Exception taxonomy** (`domain/purchase_exception.dart`, house sealed-class shape): `PurchaseCancelledException` (user cancel — flow state, not an error), `PurchasesUnavailableException` (SDK unconfigured — no API key — or platform refuses), `PurchaseNotIdentifiedException` (Decision 2 guard), `PurchaseNetworkException`, `PurchaseStoreException` (store/billing problems), `PurchaseUnknownException`. One pure mapper `mapPurchasesFailure(Object)` (`data/purchases_failure_mapper.dart`) over `PurchasesErrorHelper.getErrorCode` — pure Dart, fully unit-tested with synthetic `PlatformException`s.

## Decision 2 — Identity: configure at bootstrap, logIn wired to auth state, purchase guarded

**Configure (bootstrap, both entrypoints, after Firebase init):** `configureRevenueCatIfKeyed()` (`data/`, beside `activateAppCheck` — same "platform channel stays out of test-reachable paths" placement): no-op when the key is empty, else `Purchases.configure(PurchasesConfiguration(kRevenueCatIosApiKey))`. The key arrives via **dart-define `REVENUECAT_IOS_API_KEY`** (empty default — the `APP_CHECK_DEBUG_TOKEN` pattern). RC public SDK keys are identifiers, not secrets, but with no RC account there is nothing to commit; when the account exists (operator item 0) the committed-per-flavor-const option can be revisited. **Fail-closed posture:** unconfigured ⇒ every repository method throws `PurchasesUnavailableException` ⇒ the paywall renders an honest unavailable/error state — mirroring the webhook's 503-unconfigured discipline. The adapter carries `isConfigured` (set by the bootstrap helper); `logIn`/`logOut` **no-op silently when unconfigured** (auth flows must never crash on a box without the key), while `fetchOfferings`/`purchase`/`restore` throw loudly.

**logIn wired to auth state:** `PurchasesIdentitySync` (`presentation/state/`), `@Riverpod(keepAlive: true)` notifier activated by `HayatiApp.build` (`ref.watch` — the app root is the only always-mounted widget). It listens to `authControllerProvider`: `AuthSignedIn(user.uid)` → `repository.logIn(uid)` (deduped per uid — auth streams re-emit); signed-out → `repository.logOut()`. Failures are contained (logged via `debugPrint`, never rethrown — a background sync must not take down the tree); the *enforcement* backstop is the purchase guard below. **Widget-test blast radius, accepted:** any test pumping `HayatiApp` already overrides `authRepositoryProvider`; those tests now also override `purchasesRepositoryProvider` with the fake. Screens pumped directly (the golden harness) are untouched.

**The load-bearing contract (ADR-013 Decision 3):** `Purchases.logIn(firebaseUid)` must precede any purchase, or the webhook resolves nothing and the mirror stays free. Two layers:

1. **Fake-level call-order contract test:** `FakePurchasesRepository` records an ordered call log; the pinned test drives sign-in → purchase and asserts `logIn(uid)` appears before `purchase(...)` in the log. This is the wiring proof (identity sync + controller together).
2. **Adapter guard:** `RcPurchasesRepository.purchase()`/`restore()` first check `await Purchases.appUserID` — an anonymous id (`$RCAnonymousID:` prefix) throws `PurchaseNotIdentifiedException` **before** any purchase UI can reach the store. "Anonymous purchases skip loudly" (ADR-013) becomes "anonymous purchases are structurally impossible through our UI". (The guard lives in the channel-backed adapter, so it is smoke-proven at M4.3; the *taxonomy path* is fake-tested.)

**Purchase is structurally gated behind pairing:** the paywall route and every gate mount require a `coupleId` (they are couple-scoped by signature — `isPremiumProvider(coupleId:)`), and `coupleId` exists only post-join. This **closes ADR-013's purchase-before-pairing gap for real users**: an unpaired user cannot reach a buy button.

## Decision 3 — Paywall: pure display derivation, honest states, the mirror is the only unlocker

**Display model** (`domain/paywall_offering.dart`, pure, heavily unit-tested): `derivePaywallOffering(Offerings) → PaywallOffering`:

- Package order: **annual first** (`offering.annual`), then `monthly`, then remaining `availablePackages` in server order (dedup by identifier). No annual ⇒ server order stands (honest — the dashboard decides; the annual-first *presentation* contract is proven with the mocked offerings that do carry annual).
- Per package: `priceString` **verbatim** (never re-formatted, never re-derived from `price` — TRY/SAR/USD localization is the store's job); annual carries `pricePerMonthString` verbatim when the SDK computed it (sub-label "≈ x/month"); trial = `introductoryPrice` with `price == 0` (else `freePhase != null` for M6.5) surfaced as `(count, unit)` — **trial copy is rendered from these fields via ARB plurals, never a hardcoded "7-day"**; the 7 arrives from the store config (mocked as 7 DAY in fixtures, matching the F4 product spec).
- `offerings.current == null` or an empty package list ⇒ typed `PaywallUnavailableException` — an unconfigured dashboard renders the honest error state, never an empty sheet.

**Screen state machine** (`paywall_screen.dart`, pushed via `Navigator.push` — the house imperative-push idiom — through a `showPaywall(context, coupleId:)` helper, the single entry point every gate uses):

- **Entitled** (`isPremiumProvider(coupleId:)` true) → already-premium view: confirmation copy, a *restore* action, and "manage in your App Store settings" copy (no `url_launcher` dependency this session — restraint). **No buy buttons.**
- Free → offerings fetch: **loading** (spinner) / **error** (typed: network-retry vs unavailable copy + retry via `ref.invalidate`) / **loaded** (annual-first cards, primary CTA on the first package, trial banner when the selected package carries one, one-purchase-covers-both pitch line, restore text-button).
- Purchase flow (`PaywallPurchaseController`, autoDispose, the `SoloAnswerController` manual-op discipline: re-entrant calls dropped while in flight, `ref.mounted` after every await): `Idle → InFlight(purchase|restore) → Completed(kind) | Failed(PurchaseException) | Idle` (cancel returns to Idle silently — a cancelled sheet is not an error).
- **Post-purchase honesty (mirror-is-truth):** `Completed(purchase)` renders a *processing* banner ("unlocking for both of you…") — the screen flips to entitled **only** when `isPremium` flips from the watched mirror (webhook → `subscriptions/{coupleId}` → stream). `CustomerInfo` from the purchase never unlocks UI (ADR-013: the mirror is truth; customerInfo is a hint). Same for restore: `Completed(restore)` shows "restore processed — syncing" and defers to the mirror. Consequence, stated honestly: **until the webhook is deployed (operator item 2), a sandbox purchase shows processing and no flip** — correct behavior against an undeployed backend, and exactly what the M4.3 smoke will observe end-to-end.
- **No paywall interstitials on the daily loop** (F4): the paywall is reachable only through explicit gate affordances. Proven by assertion (Decision 4), not by hope.

**Offline:** offerings fetch failures map to `PurchaseNetworkException` → the standard network-retry error view (the house `*NetworkException` convention). No connectivity plugin — inference from typed failures, the existing pattern.

**Dev-flavor posture:** with no RC key, dev renders the honest unavailable state. Mocked offerings live **test-side only** (`test/support/`); no fixture data ships in `lib/`. The founder sees the paywall through goldens until M4.3's sandbox.

## Decision 4 — Premium gate: one widget, one derived boolean, pack selection as the first gated surface

**`PremiumGate`** (`presentation/premium_gate.dart`):

```dart
class PremiumGate extends ConsumerWidget {
  const PremiumGate({required this.coupleId, required this.unlocked, required this.locked});
  // build: ref.watch(isPremiumProvider(coupleId: coupleId)) ? unlocked : locked
}
```

Deliberately minimal: the entire premium decision stays in `isPremiumProvider` (ADR-013's expiry-paired check — the gate adds **no second decision point** and can never disagree with it). Loading/error/absent already collapse to `false` inside the provider (free-until-proven). This is the single seam every later premium feature (coach at M5, packs at W9, quizzes at v1.5) mounts on.

**The first gated surface — pack selection (the only real premium surface until M5):**

- **`PackSelectionScreen(coupleId)`**: body wrapped in `PremiumGate`. **Unlocked:** the couple's current bank presented honestly (starter bank; "more packs on the way" — W9 authors real couple packs; **no `packConfig` writes this session** — `couples.packConfig` stays unmapped/unwritten, ADR-011, and a selection *write* path is W9's decision, likely a Function given the rules posture). **Locked:** lock presentation + the premium pitch + CTA → `showPaywall`. The flip is the M4.2 accept line, tested in both directions *through the real derivation chain* (a `FakeEntitlementRepository` emitting entitled/expired mirrors flips the live widget — not just a provider override).
- **Entry point on `PairedHomeScreen`**: a quiet tile (packs affordance) below the question card — always visible, lock badge when free, tap always opens `PackSelectionScreen` (the gate lives in ONE place, inside the screen; the tile never re-decides). **Accepted golden churn:** the tile appears in every existing paired-home golden — intentional re-baseline behind the W4 flag. The tile watches the same `isPremium`; existing paired-home tests without an entitlement override stay green because an un-overridden throw-until-overridden repo surfaces as `AsyncError` → `isPremium` fail-safes to `false` (free badge) — but paired-home golden arranges gain an **explicit** free-mirror override anyway (explicit > incidental).
- **Free tier untouched, by assertion:** widget tests pin that with `isPremium` false AND true, the daily loop (question card, answer entry, streak row) renders and the answer save flow completes identically; `PremiumGate` has no descendant/ancestor relationship with the question card subtree (`findsNothing` probes); no route push to the paywall occurs during the answer flow.

**Goldens** (test-suite §1, paywall is a P0 screen): `paywall_screen` `loaded` × sixCells + scale-130 naturals; `entitled` × sixCells; `pack_selection_screen` `locked` × sixCells + `unlocked` × sixCells + scale-130 naturals for the locked state; existing paired-home matrix re-baselined (tile). Deterministic via the mocked-offerings fixture: **one TRY storefront fixture across all locale cells** — storefront currency follows the store account, not the device locale, so identical price strings in every cell is the honest rendering (fidelity gap for SAR/USD display recorded for the M4.3 sandbox smoke).

## Decision 5 — Mocked offerings fixture: real SDK objects, one canonical builder

`test/support/purchases_fixtures.dart`: builders minting **real** `purchases_flutter` model objects (verified-constructible) — `anAnnualPackage()`/`aMonthlyPackage()` (TRY `priceString: '₺899,99/yıl'`-style verbatim strings, annual carries `IntroductoryPrice(0, '', 'P1W', 1, PeriodUnit.day, 7)`-shaped 7-day free trial), `aMockedOfferings()` composing the F4 shape (current offering: annual + monthly). `FakePurchasesRepository` (`test/support/fake_purchases_repository.dart`, house fake conventions: ordered **call log** for the contract test, `onFetchOfferings`/`onPurchase`/`onRestore` behavior knobs — loud `StateError` when an unarranged required knob is hit, canned success defaults where safe, `dispose()`).

## Consequences

- M4.3 (gift flow + sandbox) inherits: a seam whose types are already the SDK's (live wiring = one bootstrap override + the real API key), the paywall's processing state (what a sandbox purchase shows until the webhook flips the mirror), and the restore path. The gift flow adds its own RC semantics (`TRANSFER`, ADR-013's no-op bucket) — not touched here.
- The gate helper is the reusable seam: coach (M5) mounts `PremiumGate` and inherits the ADR-013 expiry discipline for free.
- Accepted gaps, recorded loudly: no live store data this session (operator item 0 — RC account + ASC record; sandbox purchase is M4.3's accept line); store-price fidelity for SAR/USD proven only at the sandbox smoke; `pricePerMonthString` display depends on the SDK computing it (absent ⇒ sub-label omitted); Android trial detection (`freePhase`) is mapped but unexercised until M6.5; paywall ARB copy is AI-drafted pending the founder's native register review (content-rule spirit; not a launch gate for engineering sessions per ADR-007).
- The identity-sync notifier adds one always-on listener at app root; tests pumping `HayatiApp` must override the purchases seam — a deliberate, loud requirement (throw-until-overridden), not a silent default.
- Coverage: ~5 new providers' `.g.dart` join the un-filtered lcov denominator (test-suite §4 note); the tested surface added alongside keeps the 66 ratchet safe (M4.1 landed at 86.46%).
