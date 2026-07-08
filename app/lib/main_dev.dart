import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/auth/data/google_auth_gateway.dart';
import 'features/auth/domain/auth_repository_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig(flavor: AppFlavor.dev);
  await initializeFirebase(config);
  runHayati(
    config,
    extraOverrides: [
      authRepositoryProvider.overrideWith(
        (ref) => FirebaseAuthRepository(
          firebaseAuth: FirebaseAuth.instance,
          googleGateway: GoogleSignInAuthGateway(),
        ),
      ),
    ],
  );
}
