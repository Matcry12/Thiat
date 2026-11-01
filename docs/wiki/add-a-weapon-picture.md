# Add a weapon picture (by hand, in the editor)

One rule: **the model scene's origin (0,0) is the grip.** It is the point where the hand holds the weapon.
The swing, the afterimages and the guard all move this point. If the handle is not on it, the sword looks "off" in the hand.

## Steps (example: a new "iron sword")

1. In the FileSystem dock, duplicate `scenes/weapons/wooden_sword_model.tscn` (it is the worked example). Name it `iron_sword_model.tscn`.
2. Open it. Select `Art` and set its Texture to your new picture. Keep `Art` a Sprite2D with Texture Filter = Nearest and an integer Scale (the example uses 2).
3. Put the **hand-grip pixel on the origin** (0,0). In the example the picture is drawn diagonally (handle bottom-left), so `Art` has Rotation 45 degrees and `Offset` = minus the grip pixel (-8.5, -22.5). To fit a new picture: find the pixel on the handle just above the pommel, set Offset to minus its position, then rotate until the blade lies along +x.
4. Select `Tip` (a Marker2D) and drag it to the **end of the blade**. It only helps you check the fit. It changes nothing in the game.
5. Do not touch `Hitbox`. Reach and hit area are gameplay numbers (`arc_degrees`, the Hitbox shape), not art.
6. Duplicate `data/weapons/wooden_sword.tres` as `iron_sword.tres`. Set `Model` to your new scene.
7. In the same file, pick `Swing Motion` (for example `data/swing_motions/sword_natural.tres`). Empty = the old snap swing.
8. Start the game, give yourself the sword, press **F1**. A cyan cross shows the grip, a pink dot shows the tip.
   Swing and look: the cross should be on the handle all the time, the dot on the blade end.
   If not, go back to step 3 or 4.

## Notes
- A bigger picture needs no other change. Afterimages copy the real picture, so they fit any size.
- To tune the feel (hand path, wobble, afterimages) open F3 and use the "Swing ..." section. Numbers are live.
- Never move the Hitbox to "fix" the look. Move the picture.
