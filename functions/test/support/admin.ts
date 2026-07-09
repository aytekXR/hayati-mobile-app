// Shared admin-SDK plumbing for the emulator-backed suites. These suites run
// under `firebase emulators:exec` (repo root), which exports the emulator
// hosts into this process:
//   firebase emulators:exec --only auth,firestore,functions \
//     --project demo-hayati 'cd functions && npm run test:ci'
import { getApps, initializeApp } from 'firebase-admin/app';
import { Firestore, getFirestore } from 'firebase-admin/firestore';

export const EMULATOR_PROJECT_ID = 'demo-hayati';

export function requireFirestoreEmulator(): string {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (!host) {
    throw new Error(
      'This suite only runs against the firestore emulator. From the repo ' +
        'root: firebase emulators:exec --only auth,firestore,functions ' +
        "--project demo-hayati 'cd functions && npm run test:ci'",
    );
  }
  return host;
}

/** Admin Firestore bound to the emulator (rules-bypassing, like a Function). */
export function adminFirestore(): Firestore {
  requireFirestoreEmulator();
  if (getApps().length === 0) {
    initializeApp({ projectId: EMULATOR_PROJECT_ID });
  }
  return getFirestore();
}

/** Wipes the emulator's Firestore between suites (REST clear endpoint). */
export async function clearFirestoreData(): Promise<void> {
  const host = requireFirestoreEmulator();
  const response = await fetch(
    `http://${host}/emulator/v1/projects/${EMULATOR_PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  if (!response.ok) {
    throw new Error(`clearFirestoreData failed: HTTP ${response.status}`);
  }
}
