// Cloud Functions entrypoint (package.json "main" → lib/index.js after tsc).
// Excluded from unit coverage: it only runs inside the Functions runtime,
// where initializeApp() must happen exactly once before any handler executes.
import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { coachProxy } from './coach/coach-proxy';
export {
  deleteAccount,
  exportData,
  recordConsent,
  updateNotificationPrivacy,
} from './data-rights/data-rights';
export { revenueCatWebhook } from './entitlements/revenuecat-webhook';
export { createInvite } from './invites/create-invite';
export { invitePreview } from './invites/invite-preview';
export { joinInvite } from './invites/join-invite';
export { questionRollover } from './rollover/question-rollover';
export { answerReveal } from './streak/on-answer-created';
