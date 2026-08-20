# Privacy Policy

This policy explains what ikimiz collects, why, where it lives, and the choices you have. It is written to be checked against what the app actually does, not to sound impressive. If a sentence here promises something the app cannot do, that is a mistake we want to hear about.

Version 3. Effective [EFFECTIVE DATE — set on the day this revision ships].

## Who runs ikimiz

ikimiz is operated by [FOUNDER LEGAL ENTITY — to be completed by the founder], the data controller responsible for the personal data described here.

You can reach us about privacy at [CONTACT ADDRESS — to be completed by the founder].

## What we collect, and where it is kept

We collect your data electronically, by automated and partly automated means, as you use the app.

Your relationship content lives in Google Cloud Firestore, in a European Union multi-region. This includes:

- your free-text reflections and the answers you share with your partner (up to 2000 characters each)
- your profile: relationship status, question language, and tone
- couple details: the link between you and your partner, your time zone, and your streak
- coach usage counters — how many coach messages you have used, never the messages themselves
- a mirror of your subscription status
- invite records
- your notification setup: the address each of your phones can be reached at for notifications, one for each device you sign in on, and your device's own short report of whether notifications are switched on, refused, or could not be set up. The report is a status word and a time, never a message.

Some service data is not kept in the European Union, and we say so plainly rather than claim everything is in one place:

- your sign-in identifiers — your name, email, and photo from Apple or Google, and your phone number if you sign in by SMS — are held on Google's Firebase Authentication service, which is not pinned to the European region.
- crash diagnostics, collected only in the released app, are processed by Google's Crashlytics service outside the European Union. These contain your device and operating-system details, error traces, and an installation identifier. They never contain your reflections, answers, or coach messages.
- an app-integrity check (App Check) confirms requests come from the real app; its attestation is not pinned to the European region either.
- notifications are delivered through Google's Firebase Cloud Messaging and Apple's push notification service, neither of which is pinned to the European region. What travels through them is the notification itself and the address of the device it is going to.

Your relationship content is stored in the European Union. Some service data — your sign-in identifiers, crash diagnostics, and notification delivery — is processed by Google and Apple outside the European Union. We do not claim that all of your data sits in Europe, because it does not.

Your content is encrypted while stored (Firestore's default at-rest encryption, with keys managed by Google) and encrypted in transit. This is not end-to-end encryption, and we do not claim we are unable to read your content.

## Why we process your data, and on what legal basis

We state a legal basis for each purpose, because a notice that hides the basis is not a real notice.

- To run the service you signed up for — sign in, your profile, pairing with your partner, streaks, your subscription status, and the notifications described below — our basis is that this processing is necessary to perform our agreement with you. We do not wrap this in a consent request, because asking consent for something the service cannot exist without would mislead you.
- To store and show your reflections and the answers you share, and to process your coach messages in the moment — the intimate heart of the app — our basis is your explicit consent. We treat this content as sensitive, take the careful reading, and ask for one clear consent before these features begin. It is required because this content is the service itself; without it there is nothing to reflect on together. If you decline, you can still sign out, download your data, or delete your account, directly and at once.
- To host your data on Google's European infrastructure, which is a cross-border transfer under Turkish law, our basis is contract necessity together with a standard contract filed with the authority. This transfer is disclosed to you as a notice. It is not based on your consent, and withdrawing your consent to the reflective features does not stop this hosting.

Your phone's own permission to show notifications is a separate thing from the consent above, and we do not treat one as the other. If you never grant it, or you turn it off later in your device settings, nothing is delivered to you. Turning it off in your device settings does not withdraw your consent to the reflective features, and withdrawing that consent does not turn notifications off — the two controls are in different places because they do different things.

## Who else is involved

- Google (Firebase Authentication, Cloud Firestore, Cloud Functions, App Check, Crashlytics, Firebase Cloud Messaging) processes data on our instructions under Google's data processing terms.
- Apple provides the App Store, in-app purchasing, and Sign in with Apple. For the data Apple handles as the store, Apple acts as its own controller under Apple's terms. Apple also operates the push notification service that carries our notifications to your iPhone.
- RevenueCat will process subscription status on our behalf once subscriptions are connected. It is not yet configured.
- The coach is powered by Anthropic, through its Claude API. When you chat with the coach, your messages are sent to Anthropic in the moment so it can write a reply, and Anthropic processes them on our behalf. Under Anthropic's commercial API terms, it does not use your conversations to train its models. We store nothing from the coach — not on our servers, and not on your device; your messages are sent to Anthropic only in the moment, to produce the reply. Sending your coach messages to Anthropic is a cross-border transfer, covered by a standard contract.

We do not use your relationship content for advertising, and there is no advertising in ikimiz.

There is no analytics or measurement provider connected to ikimiz, and no product-analytics data leaves your phone. What the app does do is keep count of a few plain milestones — that it was installed, that you signed in, that an invite was sent, that you paired, that a question was answered, that a reveal was seen, that a streak day passed, that a coach message was sent. There is no way for one of these to contain a reflection, an answer, or a coach message: they are counts of something happening, and the code that carries them has nowhere to put text. Today they are recorded and then discarded on your phone, because there is nobody to send them to. Your phone also keeps a small marker for each milestone so the same one is not counted twice; those markers never leave the device, and removing the app removes them. If we ever connect an analytics provider, it will arrive with its own separate opt-in, off until you turn it on, naming the provider before anything is sent — never folded into the one consent this app already asks for.

## Keeping ikimiz private on your device

Some of ikimiz's privacy is on your own device, and we describe its honest limits rather than oversell it:

- You can lock ikimiz with a 6-digit PIN, with Face ID or Touch ID as an optional shortcut. This is a local protection: it blocks casual access to the app, but it is not forensic-grade and it will not defeat someone who holds your own device credentials. A person with your SIM (for the SMS code) or your device Apple ID can force a way in through account recovery — which signs you out and removes the PIN, so it leaves a trace you can see.
- The discreet app icon shows a plain icon on your home screen. The app's name still appears under it; the icon image changes, the name does not.
- ikimiz sends four kinds of notification, and all four are about your own activity: that your partner has answered today's question; that you have both answered, so the day is open; that the day's question is ready, at 9 in the morning in your couple's time zone; and a reminder at 10 in the evening if the day is still unanswered. There are no other kinds, and we send you nothing promotional.
- A notification never contains the question or an answer, in any mode. That is not a promise we keep by being careful — the code that writes notifications has no way to put question or answer text into one.
- In its ordinary form a notification can show your partner's name, as in "Aylin answered". The discreet-notifications setting takes that away: with it on, a notification says only that something is waiting for you — no name, no event, no streak count. It is on by default when your reading language is Arabic, and you can switch it on in any language.
- Nothing is sent between 11 in the evening and 8 in the morning, in your couple's own time zone.
- No notification has ever been delivered to anyone. The whole path above is built and running on our side, but it has never once worked on a real phone, and we would rather tell you that than let this section imply a feature you are receiving.

## How long we keep your data

Nothing in ikimiz expires on a timer. Your reflections and answers stay until you delete them.

- Invite codes stop working 48 hours after they are made, but the invite record itself is kept until your account is deleted.
- Deleting your account is the way your data is erased — there is no separate expiry.
- A device's notification address is removed when you sign out on that device, and again when someone else signs in on the same phone. Both of those are best-effort, and the address is removed for certain when your account is deleted. Your device's notification status report is kept until your account is deleted.
- The coach keeps nothing. Coach conversations are held only in your device's memory while you use them and are gone when you close the app or sign out; nothing is stored on our servers or on your device.
- The coach can point you toward professional help if a message sounds like a crisis. We never store a record that this happened.

## Your rights

Under Turkish data protection law you may: learn whether we process your data; ask what we hold and why; learn who it is shared with, at home and abroad; ask us to correct anything wrong; ask us to erase it; ask that any correction or erasure be notified to those your data was shared with; object to a result that affects you adversely and was produced solely by automated analysis; and seek redress if it was processed unlawfully. Two of these rights are built directly into the app:

- Download my data, in Settings, gives you a copy of your own data, inside the app, with nothing sent by email. It is strictly your own data — it never includes what your partner wrote. It shows you your device's notification status report in full, and how many of your devices are registered for notifications, but not the addresses themselves: an address is a working key to your phone, and the download is delivered through your clipboard, so handing you the key would put it somewhere you did not choose.
- Delete account and data, in Settings, permanently removes your account, your private reflections, and the entire shared space with your partner — both sides of every answer. This cannot be undone. It does not cancel an App Store subscription; you manage that in your App Store settings. It cannot un-reveal what your partner has already read or remembers. Your partner will see, calmly and inside the app the next time they open it, that the shared space was closed — not why, and with no push notification sent to them.

For the other rights, contact us at the address above.

## Your consent, and how to withdraw it

There is exactly one consent in ikimiz: your consent to process your reflections, the answers you share, and your coach messages. There are no bundled boxes and no toggles for things that do not exist.

You can withdraw this consent at any time from the legal screen in Settings. It is free, takes one confirmation, and asks nothing more of you than granting it did. When you withdraw, the reflective features pause and you will be asked to consent again if you want to use them.

Withdrawing does not delete what you have already written. Your stored reflections and shared answers remain stored until you delete them yourself — withdrawal stops nothing that is already saved. If you want that content gone, use Delete account and data, which is offered right beside the withdraw action.

## Changes to this notice

This is version 3. Version 3 describes the notification system honestly. Version 2 told you that ikimiz does not send push notifications; that was true of what anyone had received and false of what the app does, because the app already asks your phone for a notification address and stores it, and our servers already compose and send. Version 3 names that address and your device's notification status report among the things we collect, names Google's and Apple's notification services among the recipients, and states the limits — no question or answer text, quiet hours, the discreet setting, and the fact that nothing has actually been delivered yet. Version 3 also corrects what version 2 said about analytics: the app now keeps count of a few plain milestones, and although none of it leaves your phone and no provider is connected, saying there was nothing there would have left you with the wrong picture. Because version 3 names data we had not named and recipients we had not named, we ask every existing user to consent again before the changed processing continues. If we make a further material change, we will update this notice, raise its version, and ask you to consent again before the changed processing begins.

## Contact

Questions about your privacy or this notice can go to [CONTACT ADDRESS — to be completed by the founder].
