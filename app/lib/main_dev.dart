import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/firebase/app_check_bootstrap.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/firebase/google_sign_in_config.dart';
import 'core/observability/crashlytics_bootstrap.dart';
import 'core/storage/local_flag_store.dart';
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
import 'features/profile/data/firestore_profile_repository.dart';
import 'features/profile/domain/profile_repository_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig(flavor: AppFlavor.dev);
  await initializeFirebase(config);
  // Both must follow initializeFirebase (they resolve the default FirebaseApp)
  // and must stay out of initializeFirebase itself: each drives a platform
  // channel that throws in the plain test VM, where the bootstrap is unit-tested
  // (docs/architecture.md §2). Dev keeps Crashlytics collection off.
  await activateAppCheck(config);
  final crashReporter = await initializeCrashlytics(config);
  // Configure RevenueCat when the dart-define key is present (ADR-014
  // Decision 2). A no-op without a key — the paywall then renders the honest
  // unavailable state — and, like App Check, kept off any test-reachable path
  // (it drives a platform channel).
  await RcPurchasesRepository.configureIfKeyed();
  // Before the first frame: the paired home computes the couple dayKey from
  // the STORED timezone (ADR-011) and needs the tz database loaded (also
  // lazily guarded inside coupleDayKey — this just front-loads the parse).
  ensureCoupleTimeZonesInitialized();
  // The local-flag store (ADR-017 Decision 4) is the app's first local
  // persistence: await SharedPreferences once here so the disclaimer gate reads
  // its ack SYNCHRONOUSLY off the in-memory cache getInstance() populates, and
  // bind it BY VALUE below.
  final prefs = await SharedPreferences.getInstance();
  final googleConfig = googleSignInConfigFor(config.flavor);
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
        (ref) =>
            FirestoreCoupleDayRepository(firestore: FirebaseFirestore.instance),
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
    ],
  );
}
