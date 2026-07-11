// Production MessagingPort over firebase-admin/messaging (ADR-012 decision 3).
// This is the ONE piece of the notification layer that cannot run in-process:
// FCM has no emulator, so send() is never observed by the vitest suite and this
// file is coverage-excluded (see vitest.config.ts, same rationale as
// src/index.ts — runtime-only wiring). It is deliberately trivial: translate the
// port's {token, title, body} into the minimal FCM notification message and hand
// it to getMessaging().send. All policy (quiet hours, discreet copy, recipient
// resolution) lives in the covered pure modules; nothing decidable lives here.
import { getMessaging } from 'firebase-admin/messaging';

import type { MessagingPort } from './messaging-port';

export class FcmMessagingPort implements MessagingPort {
  async send(message: { token: string; title: string; body: string }): Promise<void> {
    await getMessaging().send({
      token: message.token,
      notification: { title: message.title, body: message.body },
    });
  }
}
