# XodOS — AI-native UX design

Renamed 2026-11-07: TreeOS is now **XodOS**. Still a real OS — a system image
with its own home, suite, and store. The difference: the agent is not an app
on the phone. The agent *is* the phone's way of working.

The person directs. Xod does. The phone shows proof.

## (a) Home, rethought

Agent first, grid second.

- **Home is a conversation surface.** One field: talk or type to your Xod.
  Clock and date stay. Everything else is one swipe away.
- **The app grid is the second screen**, not the first. Apps are tools the
  person *and* the agent can open. Search stays.
- **Proactive cards live on home, in one stack**, newest first, dismissible:
  next calendar event, a package arriving, a photo from a year ago. Few,
  relevant, or none. An empty stack shows nothing — no filler.
- **"Needs you" has its own place.** Approval cards never sit inside the
  chat (Rene's standing rule: cards out of the conversation, their own
  space). One badge, one queue screen. A card shows: what Xod wants to do,
  why, and the one-tap answers. Nothing stacks up silently — a finished
  task's card clears itself.
- **Mail that needs a reply shows as a Needs-you card**, sourced from the
  inbox digest. The honesty rule carries over from the inbox build: a
  source that failed to read is shown as *unread*, never as empty. The
  phone never says "all handled" unless every source actually read.

## (b) How the agent controls the phone

One agent, on-device, with three hands:

1. **Intents and app tools first** — the structured way: place a call,
   send the message, set the alarm, open the app to the right screen.
2. **A tool layer over system services** — settings, files, calendar,
   notifications, the store, OS updates.
3. **Accessibility as the last resort** — for apps with no other door, the
   agent drives the screen the way a person would, and says so.

**Approval rules mirror Xod's, exactly:**

- The user sets rules once ("book rides under $40", "never send mail
  without asking"). Under the rules: the agent acts, then shows the
  receipt. Above them: a Needs-you card, before anything happens.
- Sending, spending, deleting, and sharing are always above the line the
  first time; the user can lower the line per action, per app, per amount.
- **Every action lands in an audit trail** on the phone: what was done,
  when, under which rule, and the read-back that proved it. Undo where the
  action allows it.
- A kill switch lives in the Needs-you space: pause the agent entirely,
  one tap. Paused means paused — no background actions.

## (c) First run: log in, and you're set up

No setup wizard maze. One sign-in.

1. **Sign in** with rdrive SSO. Primary route: GitHub **device code** —
   the phone shows a short code, you approve it on any other device.
   No secrets typed on the phone, none stored on it.
2. **The phone enrolls into the signed family registry** as a full member:
   it gets its own Ed25519 key, its own name, and per-device revocation —
   the same registry the computers already use.
3. **The pairing gate applies, unchanged:** the phone only joins backends
   that prove *both* signed family-registry membership *and* a logged-in
   rdrive SSO session for the same account. Either check failing means
   refusal, no partial state.
4. **It pulls the family rules and config** — approval rules, family
   rules, the stores' catalog, mail identity. Home Xods see the phone in
   **Your Xods**; the phone sees the fleet. Done. Zero further setup.

**Offline:** the phone works fully as a phone. The agent runs its
on-device abilities; anything needing the fleet queues and syncs when the
network returns. Nothing about being offline is presented as an error.

**Lost phone / revocation:** any family member device can revoke the
phone's registry entry. Revoked means: fleet access ends, family rules
stop syncing, the mailbox identity is cut. The phone itself still works
as a phone with its local data — revocation is about the family, and
remote wipe is a separate, explicit, owner-only action.

## (d) The store — ours, and what it replaces

The audit found the test base has **no working store** (the Play entry is
a license-check stub). An open build cannot ship the Play Store — it is
Google-proprietary, licensed to Google builds only. Said plainly:

- **XodOS ships its own store.** Two shelves: a curated open catalog
  (proven open-source apps — the Fossify set, K-9/Thunderbird, an
  F-Droid-class catalog underneath) and **first-party apps**: the XodOS
  suite and Xod itself.
- **Everything in our store is signed**, and the store verifies the
  signature before install and before every update. Our own apps are
  signed with the XodOS release key.
- **The store is also the OS update channel.** XodOS image updates arrive
  as store items: download, verify signature and hash, stage, reboot to
  apply (or DSU-try first). The GMS updater surface in the test base is
  replaced by this — updates become ours end to end.
- **Sideloading stays on**, with the standard Android consent prompt.
  It's the user's phone. The store warns on unsigned APKs; it does not
  block them.
- **What replaces Play, honestly:** our store + F-Droid-class catalogs +
  web apps cover open software well. Some proprietary apps only exist on
  Play; on an open build those are reachable only by sideloading the APK
  or using the web version. We say that on the box, not in fine print.

Store v1 scope is the sibling lane's build; this doc fixes its role:
catalog + first-party shelf + OS updates, signed throughout.

## (e) Look and feel

Simple. Show, don't tell. Five principles for the polish work:

1. **One surface, one job.** Home talks, Queue decides, Grid launches,
   Store installs. No screen does two jobs.
2. **Copy is a last resort.** A headline and one short line per screen,
   maximum. Icons, receipts, and demos carry the story.
3. **Proof over promises.** Every "done" shows its evidence — the sent
   message, the booked ride, the changed setting — one tap deep.
4. **Calm by default.** Dark green, quiet surfaces, nothing moves or
   badges unless it needs the person. The phone asks rarely and means it.
5. **The agent is visible.** When Xod is acting, the phone shows it —
   a small live line ("Booking your ride…"), never silent magic.

## (f) What ships when

| Version | What |
|---|---|
| **v0.5** (running) | XodOS rebrand + polish: name, branding, About page identity (model/brand read XodOS), timezone defaults |
| **Store v1** (queued, sibling lane) | The XodOS store: curated open catalog + first-party shelf, signed APKs, sideload policy |
| **Agent home** (next design → build slices) | §(a)+(b): conversation home, Needs-you queue, approval rules, audit trail — built slice by slice on the emulator image first |
| **Fleet login** (with agent home) | §(c): SSO sign-in → registry enrollment → fleet sees the phone |
| **GSI on Pixel** (see PHONE-PRODUCT.md) | The same content spec built for arm64; DSU test on a real Pixel, then flash |
| **OTA** (after GSI) | OS updates delivered through our store, §(d) |
| **v0.7** (queued behind Store v1) | Emulation, §(g): Emulation screen, store emulator catalog, install-from-Downloads, `Emulation/` folder structure |

Naming note: the launcher package stays `dev.treeos.launcher` through
v0.5 — the rename is product-facing (name, branding, store, docs). The
package id changes, if ever, only as part of a deliberate image rebuild,
never as a silent swap under existing installs.

## (g) Emulation

Emulation is a first-class place in the OS, not a folder of loose apps.

- **One Emulation screen** shows the emulators you have installed, each
  with its systems and your game library under it.
- **Get more from the store.** The XodOS Store carries an emulator
  catalog: direct downloads of emulator APKs from their official
  sources, hash-verified before install — the same signed-and-checked
  treatment as everything else in the store. We do **not** bundle
  emulators with the OS, and we never ship games or ROMs.
- **Install what you downloaded.** An install-from-Downloads surface in
  the Emulation screen: pick an APK or package you fetched yourself,
  see its source and hash, install it with the normal consent.
- **Your files, organized.** XodOS keeps an `Emulation/` folder
  structure — one folder per system — that emulators can scan, so a
  person's own game files stay in one known place instead of scattered
  through Downloads.
- **The agent can set it up.** Ask your Xod for an emulator and it
  fetches it from the catalog, installs it, and lays out the folders —
  under the same approval rules as everything else: downloads and
  installs are above the line until you say otherwise.

## (h) The Orb — the agent home has a face

The agent of §(a) is a character: the **Orb**, top-center on home,
always present. It shows state by moving (idle, listening, thinking,
celebrating, asleep) and glows when the Needs-you queue needs you —
the cards stay in the queue, never in the chat. Tap it to talk;
long-press for the character sheet. The character slot holds Xod by
default, or **your Muse** when you connect it — avatar, name, and
vibe port over. Its moves are video clips in named slots, and new
ones can be generated, so the character grows. Full design:
[CHARACTER-ORB.md](CHARACTER-ORB.md).
