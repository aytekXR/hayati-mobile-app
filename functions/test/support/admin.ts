// Shared admin-SDK plumbing for the emulator-backed suites. These suites run
// under `firebase emulators:exec` (repo root), which exports the emulator
// hosts into this process:
//   firebase emulators:exec --only auth,firestore,functions \
//     --project demo-hayati 'cd functions && npm run test:ci'
import { getApps, initializeApp } from 'firebase-admin/app';
import { Firestore, getFirestore } from 'firebase-admin/firestore';

export const EMULATOR_PROJECT_ID = 'demo-hayati';

// A SECOND project on the same (multi-tenant) firestore emulator that the
// functions emulator — started with --project demo-hayati — does NOT watch, so
// document-triggered Functions (M3.4 answerReveal) never fire on writes here.
// In-process service suites that seed answer docs (couples/.../answers/{uid})
// use this to test handleAnswerCreated deterministically: on demo-hayati the
// live trigger would fire on the seed and RACE the in-process drive (both would
// observe the reveal already latched). The e2e suite deliberately stays on
// demo-hayati, where the trigger IS the thing under test.
export const NO_TRIGGER_PROJECT_ID = 'demo-hayati-notrigger';

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

/**
 * Admin Firestore on the NO_TRIGGER project (a named secondary app). Writes here
 * never fire the functions emulator's document triggers — required for
 * deterministic in-process reveal-service tests (see NO_TRIGGER_PROJECT_ID).
 */
export function noTriggerFirestore(): Firestore {
  requireFirestoreEmulator();
  const existing = getApps().find((app) => app.name === 'no-trigger');
  const app = existing ?? initializeApp({ projectId: NO_TRIGGER_PROJECT_ID }, 'no-trigger');
  return getFirestore(app);
}

async function clearProject(projectId: string): Promise<void> {
  const host = requireFirestoreEmulator();
  const response = await fetch(
    `http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  if (!response.ok) {
    throw new Error(`clearFirestoreData(${projectId}) failed: HTTP ${response.status}`);
  }
}

/** Wipes the emulator's Firestore between suites (REST clear endpoint). */
export async function clearFirestoreData(): Promise<void> {
  await clearProject(EMULATOR_PROJECT_ID);
}

/** Wipes the NO_TRIGGER project between suites. */
export async function clearNoTriggerFirestore(): Promise<void> {
  await clearProject(NO_TRIGGER_PROJECT_ID);
}
