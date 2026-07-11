// The injectable send seam for M3.4 pushes (ADR-012 decision 3: "all behind an
// injectable MessagingPort seam"). FCM has NO emulator, so the SEND is the one
// operation the in-process suites cannot exercise for real — every trigger/sweep
// test injects a fake port and asserts on the {token, title, body} it receives,
// while production wires the firebase-admin adapter (fcm-adapter.ts). Keeping the
// port this thin is what makes the entire Functions half of notifications
// emulator-provable; real APNs/on-device delivery stays operator-expected item 4.
export interface MessagingPort {
  send(message: { token: string; title: string; body: string }): Promise<void>;
}
