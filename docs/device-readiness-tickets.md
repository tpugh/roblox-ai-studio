# Device-readiness tickets

Audit of all `studio/examples/*.lua` and the live place, focused on fixed-size views
and device-specific input. Console is currently disabled on the experience, so
console-only items are backlog.

Status legend: `OPEN` / `DONE` / `DEFERRED`.

---

## P0 — ship blockers

### TICKET-1 — Snowball FIRE button overlaps the touch action cluster — OPEN
**Severity:** High · **Devices:** Phones, tablets
**Evidence:** `ball_controller.client.lua:89-108` creates `SnowButtonBubble`
(230×82 at `UDim2.new(1,-18, 1,-104)`, anchor `(1,1)`). After `applyScale()` the
DUNK (`≈861,300`) and TRICK (`≈804,323`) circles land inside its rect. Reachable
when the player buys Snowball Cocoa. No mobile handling exists and no `DisplayOrder`
is set on any ScreenGui, so tap ownership is undefined.
**Fix:** Hide `SnowButtonBubble` (+ shadow) on touch and add a SNOW circle to the
cluster that fires the same snowball action; set an explicit `DisplayOrder` for
`MobileControls`.
**Acceptance:** With the snow gun owned, every action and FIRE is tappable with no
overlap; layering is deterministic.

### TICKET-2 — Portrait phones push action buttons off-screen — OPEN
**Severity:** High · **Devices:** Phones (portrait), narrow tablets
**Evidence:** `mobile_controls.client.lua:61-68,190-233` scales by viewport height
only (`clamp(viewport.Y/720, .6, 1.15)`) and multiplies right/bottom offsets. At
390×844 the scale is 1.15 → STEAL center is 443px from the right edge of a 390px
screen, entirely off-screen; TRICK/BREAKER at 397px are also off.
**Fix:** Derive scale from `min(W,H)`, clamp final centers inside the viewport, and
re-run on `ViewportSize` change (listener already exists).
**Acceptance:** All 8 buttons visible and tappable in 390×844, 844×390, 1024×460,
tablet and desktop, with no inter-button overlap.

### TICKET-3 — Spectator camera can stick, has no exit, and misdirects throws — OPEN
**Severity:** High · **Devices:** All (worst on phones/tablets)
**Evidence:** Duplicate `WatchGame` handlers at `ball_controller.client.lua:291-313`
and `cocoa_shop.client.lua:390-411` both set `CameraType=Scriptable` with the same
fixed 16:9 CFrame and run independent 12s restore timers. No cleanup on respawn,
shop open, or dunk; no early exit; no aspect compensation. `mobile_controls.client.lua:133-137`
uses the Scriptable camera's LookVector for SHOOT.
**Fix:** Single owner module + token guard; explicit `StopWatching`; cancel on
`CharacterAdded`, shop open and dunk; aspect-aware FOV; EXIT button; use
`HumanoidRootPart.LookVector` while spectating. Remove the duplicate handler.
**Acceptance:** Camera always restores; view fits portrait; touch/gamepad can exit;
a dunk cancels spectating.

### TICKET-4 — Mobile jump is removed instead of repositioned — OPEN
**Severity:** High · **Devices:** Phones, tablets, hybrid touch laptops
**Evidence:** `mobile_controls.client.lua:48-55` unbinds `jumpAction` on touch, but
DUNK requires a held ball, so a player without a ball cannot jump. On touch laptops
this also kills Space/gamepad jump.
**Fix:** Remove the unbind (the cluster now sits left of the default jump button);
keep default jump and add an explicit JUMP circle only if overlap reappears.
**Acceptance:** Jump works on phones and hybrid laptops; no overlap with SHOOT.

---

## P1 — phone/tablet polish

### TICKET-5 — Pop-up HUD wider than narrow viewports — OPEN
**Severity:** Medium · **Evidence:** `FlashBubble` 840/940px and `ChainBubble` 760px
use fixed 0.55 factors; at 390px wide they still clip (`mobile_controls.client.lua:246-254`).
**Fix:** Compute each scale from `viewport.X` and reapply on resize, like shop menus.
**Acceptance:** No pop-up exceeds viewport width in any orientation.

### TICKET-6 — Missing touch actions (dribble/catch, music) — OPEN
**Severity:** Medium · **Evidence:** No DRIBBLE/CATCH or MUSIC circle;
`MusicMuteToggle` is created but never fired (`mobile_controls.client.lua:26-31,199-218`).
**Fix:** Add both circles; wire DRIBBLE to `DribbleRemote` and MUSIC to `MusicMute:Fire()`.
**Acceptance:** Every desktop action has a touch equivalent; music can be muted on touch.

### TICKET-7 — `slimHUD` is all-or-nothing — OPEN
**Severity:** Medium (robustness) · **Evidence:** One early `return` if any of 6
targets is missing cancels all HUD slimming (`mobile_controls.client.lua:255-259`).
**Fix:** Make each spec independent; retry per-spec.
**Acceptance:** A missing `StreetHUD` does not undo wallet/score slimming.

### TICKET-8 — Leftover full-size HUD + keyboard text — OPEN
**Severity:** Medium/Low · **Evidence:** `ChargeBubble` (340×30) and `BreakerBubble`
(400×46) are not slimmed; `BreakerBubble`'s label still says "X trick · G dunk ·
Shift turbo" (`nba_street_hud.client.lua:145,149`).
**Fix:** Add both to `slimHUD`; give `meterLabel` a touch-neutral string.
**Acceptance:** No keyboard command text visible on touch; all bubbles consistent.

### TICKET-9 — Charge can stick when GUI is disabled — OPEN
**Severity:** Medium · **Evidence:** Hold-to-charge uses `MouseButton1Down/Up/MouseLeave`
(`mobile_controls.client.lua:108-118`); a cancelled touch or shop opening mid-charge
leaves `charging=true`, so the next tap fires a full-charge shot.
**Fix:** Track the `InputObject`, listen to `InputEnded`, reset charge when
`gui.Enabled` flips false, add a max-charge timeout.
**Acceptance:** No phantom full-charge shot after a cancelled touch or closed shop.

---

## P2 — backlog / robustness

### TICKET-10 — Shop tap targets below 44px after UIScale — DONE
**Severity:** Low · `close` 80×38→~30px, `robuxClose` 44×36→~29px, `buy`/`remove`
~36px at scale 0.793 (`cocoa_shop.client.lua:171-180,319-321,230-232,359-361`,
`santa_workshop.client.lua:232-241,288-290,355-357`).
**Fix:** Enforce ≥44px effective size on touch.
**Acceptance:** Every shop button ≥44px effective on a 1024×460 viewport.

### TICKET-11 — Safe area and explicit layering — DONE
**Severity:** Low · `IgnoreGuiInset=true` on all GUIs ignores notched-phone safe
areas; no `DisplayOrder` anywhere.
**Fix:** Add safe-area padding for `MobileControls`; assign intentional `DisplayOrder`
values (HUD < controls < modal).
**Acceptance:** Nothing hidden under the notch; modal always above controls.

### TICKET-12 — BillboardGui scaling is too coarse — DONE
**Severity:** Low · Flat `×0.65` / `MaxDistance×0.75` (`mobile_controls.client.lua:344-353`)
can still let close-up signs dominate short viewports.
**Fix:** Distance/aspect-aware scale.
**Acceptance:** No sign covers more than ~25% of viewport height at typical range.

### TICKET-13 — Device-neutral spectator sign text — DONE
**Severity:** Low · "press E to watch" is rewritten only on touch
(`mobile_controls.client.lua:337-343`).
**Fix:** Use "Interact to watch" or derive from `GetLastInputType()`.

### TICKET-14 — Console gamepad bindings — DONE
**Severity:** High if console enabled · Core actions are keyed only
(`ball_controller.client.lua:194-244`, `nba_street_hud.client.lua:209-225`).
**Fix:** Move bindings to `ContextActionService` with keyboard + gamepad + touch.
**Acceptance:** All actions playable on gamepad before console is enabled.

---

## Already mitigated (no ticket)
- Score/wallet/scoreboard/pop-up HUD bubbles: shrunk and see-through.
- Keyboard hint bars, Holiday Piano "M mute" tag, announcer title board: hidden on touch.
- Shop menus: `UIScale` fit; controls hidden while a shop is open.
- In-world "press E" sign: touch text rewritten.
- Dunk stuck-at-rim bug: fixed (timed waits + unconditional cleanup + watchdog).
