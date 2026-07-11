// In-process MessagingPort double for the M3.4 push suites (ADR-012 decision 3:
// FCM has no emulator, so the SEND is never real — every trigger/service test
// injects this and asserts on the {token, title, body} messages it captured).
// `failTokens` lets a test force a per-token send failure to prove the service
// counts it and never throws (the transactional reveal must survive a bad send).
import type { MessagingPort } from '../../src/notifications/messaging-port';

export interface SentMessage {
  token: string;
  title: string;
  body: string;
}

export class FakeMessagingPort implements MessagingPort {
  readonly sent: SentMessage[] = [];
  private readonly failTokens = new Set<string>();

  /** Make send() reject for this token (simulates an FCM delivery error). */
  failOn(token: string): void {
    this.failTokens.add(token);
  }

  async send(message: SentMessage): Promise<void> {
    if (this.failTokens.has(message.token)) {
      throw new Error(`fake fcm send failed for ${message.token}`);
    }
    this.sent.push(message);
  }
}
