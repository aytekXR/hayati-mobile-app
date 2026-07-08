import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/firebase/google_sign_in_config.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/auth/data/google_auth_gateway.dart';
import 'features/auth/domain/auth_repository_provider.dart';
import 'features/profile/data/firestore_profile_repository.dart';
import 'features/profile/domain/profile_repository_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig(flavor: AppFlavor.dev);
  await initializeFirebase(config);
  final googleConfig = googleSignInConfigFor(config.flavor);
  runHayati(
    config,
    extraOverrides: [
      authRepositoryProvider.overrideWith(
        (ref) => FirebaseAuthRepository(
          firebaseAuth: FirebaseAuth.instance,
          googleGateway: GoogleSignInAuthGateway(
            clientId: googleConfig.iosClientId,
            serverClientId: googleConfig.serverClientId,
          ),
        ),
      ),
      profileRepositoryProvider.overrideWith(
        (ref) =>
            FirestoreProfileRepository(firestore: FirebaseFirestore.instance),
      ),
    ],
  );
}
