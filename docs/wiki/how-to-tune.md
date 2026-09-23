# How to change the numbers yourself

Two ways. Start with **Way 1** — it is faster and you see the result immediately.

---

## Way 1 — While playing (F3)

Best for: finding the right number by feel.
Changes are **temporary** until you press Save.

### Steps

1. Open the **editor**: `godot -e .` inside the project folder.
   (`godot .` without `-e` runs the game instead of opening the editor.)
2. Press **F5** to play. The game window opens next to the editor.
3. Press **F3**.
   - Left side = live information (fps, position, weapon state, hit rate).
   - Right side = a list of sliders.
4. Find the group you want. Groups have a heading like `-- Sword --`:

   | Group | What is inside |
   |---|---|
   | `-- Player --` | Speed |
   | `-- Sword --` | Damage, Windup, Active, Recovery, Arc Degrees, Reach |
   | `-- WeaponVisual --` | Hand Distance, Rest Angle, Art Angle, Windup Angle |
   | `-- Visual --` | Run Bob, Bob Speed |
   | `-- Dummy Health --` | Max HP, Armor |
   | `-- Debug --` | Overlay toggles |

5. **Drag a slider.** The number next to it updates. The game uses it **immediately** —
   swing again and you feel the change.
6. Keep playing. Try it, change it, try again.
7. When it feels right, press **Save** (top of the slider column).
   This writes the numbers to a file so they survive closing the game.
8. Tell me you saved. I will put the numbers into the project files permanently.

### The buttons

| Button | What it does |
|---|---|
| **Save** | Keep your numbers |
| **Load** | Get your saved numbers back |
| **Reset** | Go back to the original numbers |
| **Heal dummy** | Refill the red enemy's health |
| **Reset stats** | Set the hit counters back to zero |

Press **F1** at the same time to see the hitboxes while you tune.
Press **F2** for slow motion — useful for checking swing timing.

---

## Way 2 — In the editor (the usual way)

Best for: everything. This is how Godot is normally used.

### Live editing while the game runs (Remote tab)

1. Open the editor: `godot -e .`
2. Press **F5**. The game window opens beside the editor.
3. In the editor's **Scene** panel (top left) a **Remote** tab appears while the game runs.
4. Click **Remote**, then click a node. The **Inspector** on the right shows its live values.
5. Change a value — **the running game updates instantly**.
6. Remote changes are temporary. To keep one, switch to the **Local** tab and set the same
   value there, then **Ctrl+S**.

### Editing the scene directly

1. In Godot, look at the **FileSystem** panel (bottom left).
2. Double-click `scenes/player.tscn`. The scene opens.
3. On the left you see the node list:

   ```
   Player
   ├── CollisionShape2D
   ├── Visual          <- the character picture
   │   ├── Body
   │   └── Shadow
   ├── WeaponVisual    <- the sword
   │   └── Blade
   ├── Hurtbox         <- where you can be hit
   ├── Hitbox
   └── WeaponHolder
   ```

4. **Click a node.** Its settings appear in the **Inspector** panel (right side).
5. Change a value. Press **Enter**.
6. Press **Ctrl+S** to save the scene.
7. Press **F5** to play and see the result.

### Where each thing lives

| I want to change | Click this node | Setting |
|---|---|---|
| How high the sword is held | `WeaponVisual` | Transform > Position > y |
| How far out the sword is | `WeaponVisual` | Hand Distance |
| Sword tilt | `WeaponVisual` | Rest Angle Degrees |
| Sword size | `Blade` | Transform > Scale |
| Grip position on the sword | `Blade` | Offset |
| The sword picture | `WeaponVisual` | Blade Texture |
| The character picture | `Visual` | Body Texture |
| Character picture position | `Visual` | Body Offset |
| Size of the "can be hit" circle | `Hurtbox/CollisionShape2D` | Shape > Radius |

Weapon numbers (damage, reach, timing) are **not** in the scene. They live in
`data/weapons/sword.tres` — double-click it, and the Inspector shows the same
numbers as the F3 sliders.

---

## If something breaks

Nothing is ever lost. Every version is saved. Run this to see the history:

```bash
cd /home/matcry/Developer/BossFight && git log --oneline
```

Then tell me, and I can put any file back to how it was.

## While you are editing

Tell me **which file** you are working on. I will not touch it until you say you are done.
This avoids us both changing the same file and losing work.
