// Cloud Functions entrypoint (package.json "main" → lib/index.js after tsc).
// Excluded from unit coverage: it only runs inside the Functions runtime,
// where initializeApp() must happen exactly once before any handler executes.
import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { createInvite } from './invites/create-invite';
export { invitePreview } from './invites/invite-preview';
