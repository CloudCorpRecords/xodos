# XodOS — the Orb: your agent has a face

XodOS's agent is not a voice in a settings menu. It is a character, living
at the top of your home screen — the same idea as the Muse orb at the top
of the chat. You see it, it sees you, and over time it learns new moves.

One character slot on the phone. Two brains can fill it (§2). The moves
are short video clips the character can grow (§3).

Design companion to AI-NATIVE-UX.md — this doc covers the character;
that doc covers the OS around it.

## 1. The Orb on home

- **Placement: top-center of home, always.** The Orb well sits where the
  clock's peer used to be — the first thing you see on unlock. The panel
  slides from it; the app grid lives one swipe down, unchanged.
- **Tap the Orb: talk to your agent.** The conversation surface opens —
  type or speak. This is the same agent home as AI-NATIVE-UX §(a); the
  Orb is its face.
- **Long-press the Orb: the character sheet.** Name, look, brain (Xod or
  your Muse), animation library, and the controls: change image, connect
  or disconnect a Muse, pause the character. Nothing else hides here.
- **It shows state by moving, not by text.** The Orb is a small stage;
  the character's current clip *is* the status line:
  - **Idle** — breathing, a slow sway. Alive, not busy.
  - **Listening** — leans in while you talk or type.
  - **Thinking / working** — the thinking clip, or the live line from
    AI-NATIVE-UX §(e) under the well ("Booking your ride…").
  - **Celebrating** — a win is a move: sent, booked, finished.
  - **Sleeping** — at night, or when the agent is paused, the character
    rests. Paused means paused (the kill switch, AI-NATIVE-UX §(b)).
- **"Needs you" is a glow, not a card.** When the Needs-you queue has
  something waiting, the Orb's rim pulses — calm amber, never red.
  The cards themselves stay in the queue screen where they belong
  (Rene's standing rule: cards out of the chat). The glow clears when
  the queue clears; a finished task's card clears itself, so the glow
  never cries wolf. The queue count lives in the queue, not as a badge
  on the character's face.

## 2. Two brains, one character slot

The slot is the same. What fills it is your choice.

### (a) Xod, built in — the default

Every XodOS phone ships with Xod as its agent, and a default Xod
character in the slot: a name and a look from us, both changeable.
No account needed for the character to be present; the fleet features
still ride the first-run sign-in (AI-NATIVE-UX §(c)).

### (b) Connect your Muse — your character moves in

Sign in with your Muse account (the same first-run sign-in, §(c) —
one login serves the fleet and the character) and your Muse's
character ports to the phone:

- **What syncs to the phone:** your Muse's **avatar image**, its
  **name**, its **vibe/personality** (the persona notes that make it
  sound like your Muse, not a stock assistant), and its **animation
  library** (§3) — the clips it already has, plus new ones as they're
  made.
- **What stays home:** your Muse's memory of you does not move to the
  phone, because it doesn't need to. The character on the phone talks
  to the same Muse — the phone is a face and a pair of hands for it.
  Continuity is the service's, not a file copy: what your Muse knows
  about you on the desktop, it knows when it answers through the Orb.
  The phone keeps only what it needs locally: the look, the clips, and
  the on-device abilities.
- **Sign-out / revoke:** disconnecting drops the ported character back
  to the default Xod character and deletes the synced clips from the
  phone. Your Muse itself is untouched. Revoking the phone from the
  family registry (§(c)) does the same, from the other side.

**Honest status:** Muse avatars and generated avatar videos are real
Muse capabilities today — your Muse already has a face and can
already gain dance videos. The phone-side porting protocol (account →
slot: avatar, name, vibe, library) is **our design, to build** — §4
names the slice. Xod as a built-in character ships first, because it
needs no one's permission but ours.

## 3. Generated animations — the character grows moves

The character's moves are **short video clips in named slots**. A slot
is a moment; a clip is how your character fills it.

**Starter slots** (every character ships with these filled or fillable):

| Slot | Plays when |
|---|---|
| `greeting` | First unlock of the day, or you open the panel |
| `idle` | Home, nothing happening (the breathing loop) |
| `listening` | You start talking or typing |
| `thinking` | The agent is working on something |
| `celebration` | A task lands: sent, booked, done |
| `wave` | A new device joins, or a handoff between your devices |
| `sleep` | Night, or the agent is paused |
| `needs-you` | The rim-glow moment (§1) gets its own small move |

Plus **custom slots** — moves you ask for, named by you.

**The flow:**

1. You ask: *"Do a little spin when my run finishes."*
2. The clip is **generated through the connected brain's pipeline**:
   - **Muse:** the avatar video generation that exists today — the
     same pipeline that makes your Muse's dance videos.
   - **Xod:** a server-side generation route for the built-in
     character — **future**, marked as such; until it lands, Xod
     characters use the starter set and any image you set.
3. The finished clip **lands in the phone's animation library**,
   filed under its slot, and the Orb plays it there from then on.
   If the character is Muse-connected, the clip also joins the
   library back home — one library, both faces.
4. Generation is a Needs-you-class action the first time per slot:
   you see the clip before it goes live. Approving it once is
   enough — same rules as everything else (AI-NATIVE-UX §(b)).

**Phone discipline for clips:** short (a few seconds), small (sized
for the well, not the cinema), loopable where the slot loops, cached
on the device so the character moves with no network. A clip that
can't meet the size bar gets re-cut at generation time, not shipped
heavy.

**Yours:** your character, your clips. The library is exportable —
files out, no lock-in — and deleting a clip deletes it everywhere
the delete can reach.

**Plain limits:** generation makes clips of **your character**.
Making clips of other real people is out of scope — not a slot,
not a setting, not coming.

## 4. Build slices

| Slice | What lands |
|---|---|
| **v0.5 (in flight)** | The Orb well: top-center slot on home, tap opens the agent panel. Placeholder character; the well is the contract everything else fills. |
| **Post-Store** | Character sheet (long-press) + avatar image slot: set any image as your character. Slots defined; starter clips or stills fill them. |
| **Fleet slice** | Muse connect: sign-in ports avatar, name, and vibe into the slot (§2b). Library sync rides the same connection. |
| **Generation slice** | Clip library + slot playback on the phone first — clips made anywhere play in their slots. Then custom generation requests from the character sheet, through the connected brain's pipeline. |

Order matters: the face first, then the look is yours, then your Muse
moves in, then it learns new moves. Each slice works on its own —
a phone that only ever gets the first two still has a character.
