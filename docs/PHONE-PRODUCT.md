# XodOS — the sellable phone

Direction set 2026-11-07: XodOS eventually ships as a phone. We flash our
OS onto Google Pixel hardware and sell the result. This doc records the
hardware call and the honest path from here to there.

## Pixel 8 vs Pixel 9

| | Pixel 8 | Pixel 9 |
|---|---|---|
| Released | Oct 2023 (Tensor G3) | Aug 2024 (Tensor G4) |
| Google support until | **Oct 2030** (8a: May 2031) | **Aug 2031** (9a: Apr 2032) |
| Bootloader | Unlockable on unlocked (non-carrier) units; carrier variants (esp. Verizon) can be permanently locked — buy unlocked, verify OEM unlocking on the unit | Same |
| GSI / DSU | Full Treble, DSU supported, fastboot flash supported | Same, one generation newer vendor |
| Units | Cheapest route in: used/refurbished plentiful | Newer, pricier; 9a is the value pick of the family |
| Support runway left | ~4 years | ~5 years |

**Recommendation: Pixel 9 (or 9a) for anything we sell; Pixel 8 for
development units.** The extra year of vendor support is the year a
customer's phone stays safe, and per-unit cost difference is small next
to support cost. Dev and test units should be the cheaper 8 — buy two,
keep one stock as the control.

Buying rule for both: **unlocked units only**, OEM unlocking toggle
verified on the actual device before it's counted as stock.

## What "our phone" means at v1 — honestly

- We ship **our software on Google's hardware**. The box contains a
  Pixel Google made, running XodOS we made. Support splits accordingly:
  hardware failures are the hardware's story; the OS, the agent, the
  store, and updates are ours.
- Flashing is done by us, before sale, with read-back verification —
  the same proof bar as every build here. The customer never runs
  fastboot.
- **Warranty honesty:** unlocking/flashing can affect the manufacturer's
  warranty position, and an unlocked bootloader changes the device's
  verified-boot story. We say this in the product materials. The
  longer-term fix is our own signing key with a relock step (Pixels
  support relocking with custom keys) — that is a deliberate milestone,
  not a v1 assumption.
- Price, volumes, and carrier certification are **not** v1 questions.
  v1 is a pilot batch sold as what it is: an AI-native phone for early
  users, in the open.

## From here to there

1. **GSI build** — the content spec (CONTENT-MANIFEST.md) re-run against
   an arm64 base. Interim: the surgery route on a downloaded arm64 base;
   clean route: an AOSP build host (~250 GB, Linux, 32 GB RAM) when one
   exists.
2. **DSU test on a real Pixel** — boot the GSI temporarily via DSU on a
   dev Pixel 8. Reboot restores stock. Nothing is overwritten; this is
   the safe first contact with real hardware.
3. **Flash** — `fastboot flash system` on the dev unit; verify boot,
   calls, Wi-Fi, camera, XodOS home, store, and OTA staging read-backs.
4. **Store + OTA** — the XodOS store (sibling lane) ships on the image;
   OS updates flow through it, signed.
5. **Agent home + fleet login** — the AI-native UX (AI-NATIVE-UX.md)
   lands on the image: sign in, phone joins the family, done.
6. **Pilot batch** — a small run of Pixel 9/9a units, flashed, verified
   one by one, sold with the honesty notes above.

Nothing on this list flashes a user's existing phone. Rene's S25 and
the Poco are out of scope for flashing, as before.
