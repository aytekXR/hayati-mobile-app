import { describe, expect, it } from 'vitest';

import {
  CURRENT_LEGAL_VERSION,
  DELETE_CONFIRM,
  EXPORT_QUESTION_NOTE,
  FORMAT_VERSION,
  logDataRightsEvent,
  projectCoupleAnswer,
  projectCoupleContext,
  projectDailyLane,
  projectInvite,
  projectProfile,
  projectSoloAnswer,
  projectSubscription,
  validateDeleteRequest,
  validateNotificationPrivacyRequest,
  validateRecordConsentRequest,
} from '../../src/data-rights/data-rights-core';

// Pure decision core for M6.2 data-rights (ADR-019 D2/D5/D6). Exhaustively
// testable without Firestore: the confirm literal, the override request shape,
// the PII-safe log projection (the type IS the guarantee — no uid/coupleId), and
// the export SCRUBBING rules (memberUids never crosses, only lanes[A] crosses,
// invites carry no counterpart uid).

describe('validateDeleteRequest', () => {
  it('accepts the exact confirm literal', () => {
    expect(validateDeleteRequest({ confirm: DELETE_CONFIRM })).toEqual({ ok: true });
    expect(DELETE_CONFIRM).toBe('DELETE');
  });

  it('rejects a missing / wrong / lowercased confirm', () => {
    expect(validateDeleteRequest({})).toEqual({ ok: false, reason: 'bad-confirm' });
    expect(validateDeleteRequest({ confirm: 'delete' })).toEqual({ ok: false, reason: 'bad-confirm' });
    expect(validateDeleteRequest({ confirm: true })).toEqual({ ok: false, reason: 'bad-confirm' });
  });

  it('rejects a non-object body', () => {
    expect(validateDeleteRequest(null)).toEqual({ ok: false, reason: 'not-object' });
    expect(validateDeleteRequest('DELETE')).toEqual({ ok: false, reason: 'not-object' });
    expect(validateDeleteRequest(['DELETE'])).toEqual({ ok: false, reason: 'not-object' });
  });
});

describe('validateNotificationPrivacyRequest', () => {
  it('accepts a boolean discreet', () => {
    expect(validateNotificationPrivacyRequest({ discreet: true })).toEqual({ ok: true, discreet: true });
    expect(validateNotificationPrivacyRequest({ discreet: false })).toEqual({ ok: true, discreet: false });
  });

  it('rejects a missing / non-boolean discreet and a non-object body', () => {
    expect(validateNotificationPrivacyRequest({}).ok).toBe(false);
    expect(validateNotificationPrivacyRequest({ discreet: 'true' }).ok).toBe(false);
    expect(validateNotificationPrivacyRequest({ discreet: 1 }).ok).toBe(false);
    expect(validateNotificationPrivacyRequest(null).ok).toBe(false);
    expect(validateNotificationPrivacyRequest('discreet').ok).toBe(false);
  });
});

describe('validateRecordConsentRequest', () => {
  it('accepts a boolean withdraw (grant and withdraw)', () => {
    expect(validateRecordConsentRequest({ withdraw: false })).toEqual({ ok: true, withdraw: false });
    expect(validateRecordConsentRequest({ withdraw: true })).toEqual({ ok: true, withdraw: true });
  });

  it('rejects a missing / non-boolean withdraw, a non-object body, and extra-typed shapes', () => {
    expect(validateRecordConsentRequest({}).ok).toBe(false);
    expect(validateRecordConsentRequest({ withdraw: 'true' }).ok).toBe(false);
    expect(validateRecordConsentRequest({ withdraw: 1 }).ok).toBe(false);
    expect(validateRecordConsentRequest({ withdraw: null }).ok).toBe(false);
    // The client never sends a version — a version-carrying shape is not accepted
    // as a grant; only the boolean withdraw is read.
    expect(validateRecordConsentRequest({ version: 1 }).ok).toBe(false);
    expect(validateRecordConsentRequest(null).ok).toBe(false);
    expect(validateRecordConsentRequest('withdraw').ok).toBe(false);
    expect(validateRecordConsentRequest([true]).ok).toBe(false);
  });
});

describe('logDataRightsEvent (no-content rule)', () => {
  it('carries only op/outcome/latencyMs — never a uid or coupleId', () => {
    const event = logDataRightsEvent({ op: 'deleteAccount', outcome: 'deleted', latencyMs: 42 });
    expect(event).toEqual({ op: 'deleteAccount', outcome: 'deleted', latencyMs: 42 });
    // The type signature is the guarantee; assert the projection surface too.
    expect(Object.keys(event).sort()).toEqual(['latencyMs', 'op', 'outcome']);
  });

  it('omits latency when absent', () => {
    expect(logDataRightsEvent({ op: 'exportData', outcome: 'exported' })).toEqual({
      op: 'exportData',
      outcome: 'exported',
    });
  });
});

describe('projectProfile', () => {
  it('includes client fields + Auth record + notificationPrivacy when set', () => {
    const profile = projectProfile(
      {
        status: 'married',
        contentLanguage: 'tr',
        register: 'respectful',
        createdAt: { toMillis: () => 1000 },
        notificationPrivacy: 'discreet',
        coupleId: 'couple-1', // NOT part of the profile section
      },
      { displayName: 'Aytek', email: 'a@example.com', photoURL: 'http://x/y.png' },
    );
    expect(profile).toEqual({
      status: 'married',
      contentLanguage: 'tr',
      register: 'respectful',
      createdAtMs: 1000,
      notificationPrivacy: 'discreet',
      displayName: 'Aytek',
      email: 'a@example.com',
      photoURL: 'http://x/y.png',
    });
  });

  it('omits notificationPrivacy when absent and nulls a missing Auth record', () => {
    const profile = projectProfile({ status: 'dating' }, null);
    expect(profile.notificationPrivacy).toBeUndefined();
    expect(profile.displayName).toBeNull();
    expect(profile.email).toBeNull();
    expect(profile.photoURL).toBeNull();
    expect(profile.createdAtMs).toBeNull();
  });

  it('carries the consent lane when the stored field has a valid shape (ADR-023 D4)', () => {
    const profile = projectProfile(
      {
        status: 'married',
        consent: { version: 1, acceptedAt: { toMillis: () => 4242 }, ageAttested: true },
      },
      null,
    );
    expect(profile.consent).toEqual({ version: 1, acceptedAtMs: 4242, ageAttested: true });
  });

  it('omits the consent lane on junk shapes (fail-closed, iff-set)', () => {
    // non-map
    expect(projectProfile({ consent: 'granted' }, null).consent).toBeUndefined();
    expect(projectProfile({ consent: 42 }, null).consent).toBeUndefined();
    expect(projectProfile({ consent: [1, 2] }, null).consent).toBeUndefined();
    // string / non-int version
    expect(
      projectProfile(
        { consent: { version: '1', acceptedAt: { toMillis: () => 1 }, ageAttested: true } },
        null,
      ).consent,
    ).toBeUndefined();
    expect(
      projectProfile(
        { consent: { version: 1.5, acceptedAt: { toMillis: () => 1 }, ageAttested: true } },
        null,
      ).consent,
    ).toBeUndefined();
    // missing / non-Timestamp acceptedAt
    expect(
      projectProfile({ consent: { version: 1, ageAttested: true } }, null).consent,
    ).toBeUndefined();
    expect(
      projectProfile(
        { consent: { version: 1, acceptedAt: 'yesterday', ageAttested: true } },
        null,
      ).consent,
    ).toBeUndefined();
    // missing / non-boolean ageAttested
    expect(
      projectProfile({ consent: { version: 1, acceptedAt: { toMillis: () => 1 } } }, null).consent,
    ).toBeUndefined();
    expect(
      projectProfile(
        { consent: { version: 1, acceptedAt: { toMillis: () => 1 }, ageAttested: 'yes' } },
        null,
      ).consent,
    ).toBeUndefined();
    // absent entirely
    expect(projectProfile({ status: 'dating' }, null).consent).toBeUndefined();
  });
});

describe('projectSoloAnswer / projectCoupleAnswer', () => {
  it('projects a solo answer to plain values', () => {
    expect(
      projectSoloAnswer('20260710', {
        questionId: 'solo_tr_003',
        text: 'reflection',
        answeredAt: { toMillis: () => 2000 },
      }),
    ).toEqual({ dayKey: '20260710', questionId: 'solo_tr_003', text: 'reflection', answeredAtMs: 2000 });
  });

  it('marks a couple answer revealed only when the day doc has revealedAt', () => {
    const answer = { questionId: 'q1', text: 'mine', answeredAt: { toMillis: () => 3000 } };
    expect(projectCoupleAnswer('20260710', { revealedAt: { toMillis: () => 1 } }, answer).revealed).toBe(true);
    expect(projectCoupleAnswer('20260710', {}, answer).revealed).toBe(false);
    expect(projectCoupleAnswer('20260710', undefined, answer).revealed).toBe(false);
  });
});

describe('projectCoupleContext (excludes memberUids)', () => {
  it('carries coupleId/timezone/streak/monthly count but never memberUids', () => {
    const context = projectCoupleContext(
      'couple-1',
      {
        memberUids: ['uid-a', 'uid-b'],
        timezone: 'Europe/Istanbul',
        createdAt: { toMillis: () => 5 },
        streak: { count: 3, lastMutualDate: '20260709', graceTokens: 1 },
      },
      { monthly: { monthKey: '202607', count: 12 } },
    );
    expect(context).toEqual({
      coupleId: 'couple-1',
      createdAtMs: 5,
      timezone: 'Europe/Istanbul',
      streak: { count: 3, lastMutualDate: '20260709', graceTokens: 1 },
      coachMonthlyCount: 12,
    });
    expect(JSON.stringify(context)).not.toContain('uid-b');
    expect(JSON.stringify(context)).not.toContain('memberUids');
  });

  it('nulls streak and monthly when absent', () => {
    const context = projectCoupleContext('couple-1', { timezone: 'Etc/UTC' }, undefined);
    expect(context.streak).toBeNull();
    expect(context.coachMonthlyCount).toBeNull();
  });
});

describe('projectSubscription (only lanes[A])', () => {
  const sub = {
    entitled: true,
    productId: 'premium_annual',
    periodType: 'NORMAL',
    expiresAtMs: 1_799_999_999_000,
    willRenew: true,
    store: 'APP_STORE',
    environment: 'PRODUCTION',
    lanes: {
      'uid-a': { entitled: true, productId: 'premium_annual', lastEventId: 'evt-a', updatedAtMs: 1 },
      'uid-b': { entitled: true, productId: 'premium_annual', lastEventId: 'evt-b', updatedAtMs: 2 },
    },
  };

  it('carries the summary and only the requester lane; B lane never crosses', () => {
    const projected = projectSubscription(sub, 'uid-a');
    expect(projected.summary.entitled).toBe(true);
    expect(projected.lane?.lastEventId).toBe('evt-a');
    const serialized = JSON.stringify(projected);
    expect(serialized).not.toContain('uid-b');
    expect(serialized).not.toContain('evt-b');
  });

  it('nulls the lane when the requester has none', () => {
    expect(projectSubscription(sub, 'uid-c').lane).toBeNull();
  });
});

describe('projectInvite (counterpart uid scrubbed)', () => {
  it('reports the role but never the counterpart uid', () => {
    const created = projectInvite(
      'CODE1234',
      { creatorUid: 'uid-a', joinerUid: 'uid-b', status: 'joined', coupleId: 'couple-1' },
      'uid-a',
    );
    expect(created.role).toBe('creator');
    expect(JSON.stringify(created)).not.toContain('uid-b');

    const joined = projectInvite(
      'CODE9999',
      { creatorUid: 'uid-b', joinerUid: 'uid-a', status: 'joined' },
      'uid-a',
    );
    expect(joined.role).toBe('joiner');
    expect(JSON.stringify(joined)).not.toContain('uid-b');
  });
});

describe('projectDailyLane / constants', () => {
  it('projects the daily lane and exposes the format version + note', () => {
    expect(projectDailyLane({ dayKey: '20260712', count: 4 })).toEqual({ dayKey: '20260712', count: 4 });
    expect(FORMAT_VERSION).toBe(2);
    expect(CURRENT_LEGAL_VERSION).toBe(1);
    expect(EXPORT_QUESTION_NOTE).toContain('questionId');
  });
});
