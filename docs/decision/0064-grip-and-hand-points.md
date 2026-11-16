# 0064 - Grip and Hand points (draggable markers)

**Status:** Active

## Context
Weapon pictures were placed by hand against a see-through "EditorPlayer" guide, and the hand point was an unnamed number
(`WeaponVisual.position` 0,-9, later `BodyRig.hand_offset`). Moving where a weapon is held meant moving the picture.

## Decision
- **Grip**: a `Marker2D` in each `scenes/weapons/*_model.tscn`. The user drags it along the weapon to where the hand holds it.
  At runtime `WeaponVisual._apply_grip()` moves every other Node2D child of the model (Art, Hitbox, Tip, Muzzle) by `-Grip.position`
  and puts Grip at 0,0, before the art fit. The hit-area fit (`WeaponHitFit`) allows for `Hitbox.position`, so the shape still covers
  hand .. picture tip + margin. No Grip = no shift.
- **Hand**: a `Marker2D` named `MainHandHold` in the character scene (`scenes/player.tscn`). `WeaponVisual._apply_hand()` puts WeaponVisual
  at `Hand.position + hand_nudge` (`hand_nudge` is the F3 live offset). x mirrors with the body (`SpriteActorVisual.is_facing_left()`,
  the same flag that flips the body picture); y stays. Hand is per scene: another character gets its own marker. No marker = the scene's own position.
- `BodyRig.hand_offset` was dropped (it existed for a few hours); the see-through player guide (`EditorPlayer`) is gone.
- `WeaponData.art_scale` is a float 0..4 (step 0.05, 0 = scene size). Whole sizes stay sharpest.
- `SpriteActorVisual._apply_rig_body()` never runs in the editor (the @tool script would bake runtime values, e.g. shadow x rig scale, into the scene on save).

## Why
Plug and socket: set each point once, any weapon fits any character, nothing to measure by eye.

## Consequences
- Grip up the blade = less reach in front of the hand, more behind it; the hit area follows the picture (0050, 0061).
- Tests that pin geometry must subtract the scene's Grip (or use a fixture), because the user tunes it.
- Tool target and aim direction stay measured from the player origin, not from the hand.
- In the editor the player's WeaponVisual sits at its scene position (0,0): the weapon preview is not on the Hand.
