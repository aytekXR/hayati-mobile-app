import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/widgets.dart'
    show WidgetsBinding, WidgetsFlutterBinding;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/bootstrap/boot_failure_app.dart';
import 'core/config/app_config.dart';
import 'core/firebase/app_check_bootstrap.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/firebase/google_sign_in_config.dart';
import 'core/observability/boot_trace.dart';
import 'core/observability/crashlytics_bootstrap.dart';
import 'core/storage/local_flag_store.dart';
import 'core/storage/pin_lock_store.dart';
import 'core/storage/secure_storage_pin_lock_store.dart';
import 'core/storage/shared_preferences_local_flag_store.dart';
import 'features/auth/data/apple_auth_gateway.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/auth/data/google_auth_gateway.dart';
import 'features/auth/data/phone_auth_gateway.dart';
import 'features/auth/domain/auth_repository_provider.dart';
import 'features/coach/data/functions_coach_repository.dart';
import 'features/coach/domain/coach_repository_provider.dart';
import 'features/daily_question/data/asset_question_pack_repository.dart';
import 'features/daily_question/data/asset_solo_question_pack_repository.dart';
import 'features/daily_question/data/firestore_couple_answers_repository.dart';
import 'features/daily_question/data/firestore_couple_day_repository.dart';
import 'features/daily_question/data/firestore_couple_repository.dart';
import 'features/daily_question/data/firestore_solo_answers_repository.dart';
import 'features/daily_question/domain/couple_answers_repository_provider.dart';
import 'features/daily_question/domain/couple_day.dart';
import 'features/daily_question/domain/couple_day_repository_provider.dart';
import 'features/daily_question/domain/couple_repository_provider.dart';
import 'features/daily_question/domain/question_pack_repository_provider.dart';
import 'features/daily_question/domain/solo_answers_repository_provider.dart';
import 'features/daily_question/domain/solo_question_pack_repository_provider.dart';
import 'features/data_rights/data/functions_data_rights_repository.dart';
import 'features/data_rights/domain/data_rights_repository_provider.dart';
import 'features/entitlements/data/firestore_entitlement_repository.dart';
import 'features/entitlements/data/rc_purchases_repository.dart';
import 'features/entitlements/domain/entitlement_repository_provider.dart';
import 'features/entitlements/domain/purchases_repository_provider.dart';
import 'features/pairing/data/app_links_deep_link_source.dart';
import 'features/pairing/data/functions_invite_repository.dart';
import 'features/pairing/data/http_invite_preview_repository.dart';
import 'features/pairing/data/share_plus_invite_share_launcher.dart';
import 'features/pairing/domain/deep_link_source.dart';
import 'features/pairing/domain/invite_preview_repository.dart';
import 'features/pairing/domain/invite_repository_provider.dart';
import 'features/pairing/domain/invite_share_launcher.dart';
import 'features/privacy_lock/data/local_auth_biometric_authenticator.dart';
import 'features/privacy_lock/domain/biometric_authenticator.dart';
import 'features/profile/data/firestore_profile_repository.dart';
import 'features/profile/domain/profile_repository_provider.dart';
import 'features/settings/data/channel_app_icon_switcher.dart';
import 'features/settings/domain/app_icon_switcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BootTrace.mark(BootTrace.stageMain);
  const config = AppConfig(flavor: AppFlavor.dev);
  // FAIL-OPEN BOOT (ADR-039). Every step below can throw for a reason that has
  // nothing to do with this code — a Firebase config that will not initialize,
  // a Pigeon channel that is not up, an App Attest challenge the device
  // refuses. When one did, the throwable escaped `main()`, `runApp` was never
  // reached, and iOS held the launch storyboard on screen forever: no frame, no
  // error, no crash report (the reporter is one of the four awaits), and no way
  // out but a force-quit that repeats it. That is the "loading screen is always
  // on" report, and it is unactionable by construction.
  //
  // The three steps that HAVE a meaningful degraded mode now fail open where
  // they are (App Check, Crashlytics, RevenueCat), so they never reach here.
  // What is left is genuinely fatal — chiefly `initializeFirebase` — and the
  // honest answer to fatal is a FRAME that says so and offers a retry, not a
  // splash that lies about still loading.
  try {
    await initializeFirebase(config);
    BootTrace.mark(BootTrace.stageFirebaseReady);
    // App Check and Crashlytics both resolve the default FirebaseApp, depend on
    // each other for nothing, and each drives a platform channel that throws in
    // the plain test VM — so they stay out of initializeFirebase (unit-tested,
    // docs/architecture.md §2) and OVERLAP here via the record `.wait` (ADR-022
    // Decision 1). App Check stays PRE-FRAME deliberately: a warm signed-in boot
    // opens the profile Firestore listen at first-frame build, so activation must
    // precede frame one for cold AND warm boots (ADR-022 review finding PERF-1).
    // Dev keeps Crashlytics collection off.
    final (_, crashReporter) = await (
      activateAppCheck(config),
      initializeCrashlytics(config),
    ).wait;
    BootTrace.mark(BootTrace.stageAppCheckCrashlyticsReady);
    // Configure RevenueCat when the dart-define key is present (ADR-014
    // Decision 2). A no-op without a key — the paywall then renders the honest
    // unavailable state — and, like App Check, kept off any test-reachable path
    // (it drives a platform channel). NOT deferred past the first frame despite
    // being a no-op today: doing so plants a warm-boot identity-sync landmine for
    // the first live-key session (ADR-022 Decision 3 — that session owns
    // re-sequencing this call with the RC identity-sync retry hardening).
    await RcPurchasesRepository.configureIfKeyed();
    BootTrace.mark(BootTrace.stageRcConfigured);
    // Two independent platform-channel round-trips that both must complete before
    // frame one, OVERLAPPED via the record `.wait` (ADR-022 Decision 1):
    //  - SharedPreferences (ADR-017 Decision 4), the app's first local
    //    persistence — awaited once so the disclaimer gate reads its ack
    //    SYNCHRONOUSLY off the in-memory cache getInstance() populates, bound BY
    //    VALUE below.
    //  - the device-lock record (ADR-018 Decision 2): the gate must decide frame
    //    one — an async lock check would flash couple content and the OS would
    //    snapshot that flash. A read that THROWS yields a DEGRADED snapshot (fail
    //    open for one launch, self-healed by the controller's re-read on first
    //    resume) rather than a permanent brick behind a lock that can verify
    //    nothing. readInitialLockSnapshot catches internally, so `.wait` cannot
    //    raise ParallelWaitError on it — degraded semantics are byte-unchanged.
    const pinLockStore = SecureStoragePinLockStore();
    final (prefs, lockSnapshot) = await (
      SharedPreferences.getInstance(),
      readInitialLockSnapshot(pinLockStore, reporter: crashReporter),
    ).wait;
    BootTrace.mark(BootTrace.stageLocalStateReady);
    final googleConfig = googleSignInConfigFor(config.flavor);
    BootTrace.mark(BootTrace.stageRunApp);
    runHayati(
      config,
      crashReporter: crashReporter,
      extraOverrides: [
        authRepositoryProvider.overrideWith(
          (ref) => FirebaseAuthRepository(
            firebaseAuth: FirebaseAuth.instance,
            googleGateway: GoogleSignInAuthGateway(
              clientId: googleConfig.iosClientId,
              serverClientId: googleConfig.serverClientId,
            ),
            appleGateway: SignInWithAppleGateway(),
            phoneGateway: FirebaseVerifyPhoneGateway(FirebaseAuth.instance),
          ),
        ),
        profileRepositoryProvider.overrideWith(
          (ref) =>
              FirestoreProfileRepository(firestore: FirebaseFirestore.instance),
        ),
        inviteRepositoryProvider.overrideWith(
          (ref) => FunctionsInviteRepository(),
        ),
        invitePreviewRepositoryProvider.overrideWith(
          (ref) => HttpInvitePreviewRepository(
            client: http.Client(),
            baseUri: invitePreviewUri(flavor: config.flavor),
          ),
        ),
        inviteShareLauncherProvider.overrideWith(
          (ref) => const SharePlusInviteShareLauncher(),
        ),
        deepLinkSourceProvider.overrideWith((ref) => AppLinksDeepLinkSource()),
        soloQuestionPackRepositoryProvider.overrideWith(
          (ref) => const AssetSoloQuestionPackRepository(),
        ),
        soloAnswersRepositoryProvider.overrideWith(
          (ref) => FirestoreSoloAnswersRepository(
            firestore: FirebaseFirestore.instance,
          ),
        ),
        questionPackRepositoryProvider.overrideWith(
          (ref) => const AssetQuestionPackRepository(),
        ),
        coupleRepositoryProvider.overrideWith(
          (ref) =>
              FirestoreCoupleRepository(firestore: FirebaseFirestore.instance),
        ),
        coupleDayRepositoryProvider.overrideWith(
          (ref) => FirestoreCoupleDayRepository(
            firestore: FirebaseFirestore.instance,
          ),
        ),
        coupleAnswersRepositoryProvider.overrideWith(
          (ref) => FirestoreCoupleAnswersRepository(
            firestore: FirebaseFirestore.instance,
          ),
        ),
        entitlementRepositoryProvider.overrideWith(
          (ref) => FirestoreEntitlementRepository(
            firestore: FirebaseFirestore.instance,
          ),
        ),
        purchasesRepositoryProvider.overrideWith(
          (ref) => RcPurchasesRepository(),
        ),
        localFlagStoreProvider.overrideWithValue(
          SharedPreferencesLocalFlagStore(prefs),
        ),
        coachRepositoryProvider.overrideWith(
          (ref) => FunctionsCoachRepository(),
        ),
        dataRightsRepositoryProvider.overrideWith(
          (ref) => FunctionsDataRightsRepository(),
        ),
        // The three device-privacy seams (ADR-018 D2/D1/D6). Bound BY VALUE here
        // and nowhere else, so `flutter test` never touches the Keychain,
        // local_auth, or the hayati/device_privacy channel.
        pinLockStoreProvider.overrideWithValue(pinLockStore),
        initialLockSnapshotProvider.overrideWithValue(lockSnapshot),
        biometricAuthenticatorProvider.overrideWithValue(
          LocalAuthBiometricAuthenticator(),
        ),
        appIconSwitcherProvider.overrideWithValue(
          const ChannelAppIconSwitcher(),
        ),
      ],
    );
    // Post-frame warm-up (ADR-022 Decision 1): the couple dayKey parse of the
    // 10-year tz database (ADR-011) is not needed by the first frame — that frame
    // is SignInScreen — so it runs AFTER first frame, deterministically, via
    // addPostFrameCallback rather than racing the first vsync. coupleDayKey's own
    // lazy guard stays the correctness backstop; this call is purely a warm-up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ensureCoupleTimeZonesInitialized();
    });
  } catch (failure) {
    // The boot never ends in silence. `main` is the retry: every step above is
    // idempotent (see runBootFailureApp), so re-entering is safe and it is the
    // only recovery available to someone holding a phone.
    runBootFailureApp(failure: failure, retry: main);
  }
}
