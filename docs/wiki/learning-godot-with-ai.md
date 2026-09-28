# Learning Godot to build with AI (not blind coding)

**Who this is for:** you, new to Godot, building BossFight together with an AI.
**Goal:** you do not need to *write* every line. You need to **read** what the AI wrote,
**judge** if the idea is right, and **test** it. This file tells you what to learn for that,
in what order, and where it lives in the docs.

Docs home: <https://docs.godotengine.org/en/stable/>
Check the version picker (bottom-left of the docs page) says **4.x**. We use **Godot 4.7**.

---

## 1. Why learn at all, if the AI writes the code?

The AI is fast, but it makes mistakes that look correct. If you cannot read the code, you cannot
see them. You only see "the game feels broken" and you do not know why.

**A real example from this project.** The AI wrote a check "is the enemy in front of my sword?":

```
aim.angle_to(to_target) <= half_arc
```

It looked fine. But in Godot, `angle_to` gives **negative** angles too (enemy to the left = -2.5).
A negative number is always "smaller than" `half_arc`. So enemies **behind** the player got hit.
On screen: you swing right, and an enemy on your left takes damage.

You catch this only if you know one small thing: *angles in Godot have a sign (+ or −)*.
That is what this guide is for. Not to make you a programmer, but to give you enough small
facts to say "wait, that's wrong".

---

## 2. The learning map

Learn in this order. Each level builds on the one before. For each level:

- **What it is** — in plain words.
- **In BossFight** — where you already see it in our project.
- **Read** — the docs pages. Read them, do not memorise them.
- **You know it when** — a small test for yourself.

Rough time: levels 0–4 = the first week. Levels 5–8 = the second week. Level 9+ = only when a
slice needs it.

### Level 0 — The editor, and one tiny game by hand

**What it is:** how to move around the Godot editor. Where the scene tree, inspector and
file system panels are. How to press Play.

**Why by hand:** doing one small game yourself, with no AI, gives you the "shape" of a Godot
project. After that, AI code stops looking like magic.

**Read / do:**
- [Introduction to the editor](https://docs.godotengine.org/en/stable/getting_started/introduction/first_look_at_the_editor.html)
- [Your first 2D game ("Dodge the Creeps")](https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html) — **do the whole thing.** About 2–3 hours. It teaches most of levels 1–5 in a small form.

**You know it when:** you can open BossFight with `godot -e .`, open `scenes/player.tscn`, click a
node, and change a number in the Inspector.

### Level 1 — Nodes and scenes (the most important idea in Godot)

**What it is:** a **node** is one small piece with one job (a picture, a collision shape, a
timer). A **scene** is a group of nodes saved as one file (`.tscn`), like a Lego model.
You can put a scene inside another scene, like putting a Lego car into a Lego city.

**In BossFight:** `scenes/player.tscn` is a tree of nodes:

| Node | Its one job |
|---|---|
| `Player` (CharacterBody2D) | moves and collides with walls |
| `Visual` | what the player looks like |
| `WeaponVisual/SwingPivot/Hitbox` | the area that *deals* damage |
| `Hurtbox` | the area that *receives* damage |
| `Health`, `Dodge`, `Guard` | one rule each |

This is why we can swap a circle for a real sprite later: only `Visual` changes.

**Read:**
- [Nodes and Scenes](https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html)
- [Creating instances](https://docs.godotengine.org/en/stable/getting_started/step_by_step/instancing.html)
- [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) — read after a few weeks; it explains *why* we build this way.

**You know it when:** you can look at the player tree and say which node you would change to
make the sword longer (answer: the `CollisionShape2D` under `Hitbox`, and the `Blade` picture).

### Level 2 — GDScript: just enough to read it

**What it is:** GDScript is Godot's language. It looks like Python. You need to **read** it,
not write it from zero.

**Learn these words first:**

| Word | Plain meaning | Example in BossFight |
|---|---|---|
| `extends` | "this script is a kind of ___" | `extends Resource` in `weapon_data.gd` |
| `class_name` | gives the script a name others can use | `class_name WeaponData` |
| `var` / `const` | a value that can change / cannot | `var phase` |
| `func` | a named action | `func _ready():` |
| `@export` | show this number in the Inspector (and our F3 panel) | `@export var damage := 30.0` |
| `@onready` | find this node when the scene starts | `@onready var health = $Health` |
| `$Name` | "my child node called Name" | `$Hurtbox` |
| `: float`, `-> void` | types — tell Godot what kind of value it is | `func take(amount: float)` |

**Read:**
- [GDScript basics](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html) — skim; come back when you meet a new word.
- [GDScript exported properties](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_exports.html) — **read fully.** Every feel number in this project is an `@export`.
- [Static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [Style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) — so you know what "normal" code looks like.

**You know it when:** you open `scripts/weapons/weapon_data.gd` and can explain each line out loud.

### Level 3 — The game loop, time and input

**What it is:** a game redraws ~60 times per second. Godot calls your functions at set moments:

| Function | When Godot calls it | Use it for |
|---|---|---|
| `_ready()` | once, when the node appears | setup, connecting signals |
| `_process(delta)` | every drawn frame | visuals, UI |
| `_physics_process(delta)` | every physics step (fixed rate) | movement, hit checks, timers for combat |
| `_input(event)` | when a key/mouse event happens | one-time presses |

`delta` = seconds since the last call (about 0.016). Multiply speeds by `delta`, or the game
runs faster on a faster PC.

**Input:** we never check "key W". We check an **action** named in Project Settings → Input Map
(like `attack`, `dodge`). So the player can rebind keys later.

**Read:**
- [Idle and physics processing](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html)
- [Listening to player input](https://docs.godotengine.org/en/stable/getting_started/step_by_step/scripting_player_input.html)
- [Input examples](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html) — `is_action_pressed` vs `is_action_just_pressed` matters for parry (tap F) vs block (hold F).

**You know it when:** you can explain why the dodge uses `_physics_process` and not `_process`.

### Level 4 — Signals: how nodes talk without knowing each other

**What it is:** a **signal** is a node shouting "this happened!". Other nodes can listen.
The shouter does not know who listens.

**Example:** `Health` shouts `damaged(amount)`. The HUD listens and updates the bar. The dummy
listens and flashes. `Health` does not know the HUD exists. If we delete the HUD, `Health` still works.

**In BossFight:** this is our main rule (CLAUDE.md §5): **combat shouts, visuals listen.**
`player.gd` line ~30: `weapon_holder.state_changed.connect(...)`. If an AI makes combat code
call a visual function directly, that is a red flag.

**Groups** are the second tool: a label on nodes, like a hashtag. "Give me every node tagged
`hitbox`" — without knowing where they are in the tree.

**Read:**
- [Using signals](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html) — **read fully.** Most important page after nodes.
- [Groups](https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html)
- `await` (wait for a signal): section "Awaiting signals or coroutines" in [GDScript basics](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)

**You know it when:** you can find every listener of `Health.damaged` in the project
(search for `damaged.connect`).

### Level 5 — 2D physics: bodies, areas, layers

**What it is:** Godot has different nodes for different "touching" needs:

| Node | Plain meaning | In BossFight |
|---|---|---|
| `CharacterBody2D` | something you move by code, that stops at walls | `Player` |
| `StaticBody2D` | something that never moves | `Dummy`, walls |
| `Area2D` | an invisible zone that only *detects* overlap, never blocks | `Hitbox`, `Hurtbox` |
| `CollisionShape2D` | the actual shape (circle, box) of the above | children of each |

**Collision layers and masks:** layer = "what I am", mask = "what I look for".
Example: the player's `Hitbox` looks for enemy hurtboxes, not the player's own `Hurtbox`.
Wrong layers = you hit yourself, or hit nothing.

**Read:**
- [Physics introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html) — especially "Collision layers and masks".
- [Using CharacterBody2D](https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html)
- [Using Area2D](https://docs.godotengine.org/en/stable/tutorials/physics/using_area_2d.html)
- Our own: [docs/reference/godot/combat-patterns.md](../reference/godot/combat-patterns.md)

**Trap we already hit:** `area_entered` does **not** fire if the enemy was *already inside*
the zone when it switched on. A sword swinging at a dummy that stands still = no hit. So
`hitbox.gd` asks "who is overlapping right now?" (`get_overlapping_areas()`) instead.

**You know it when:** you press F1 in game and can say which drawn shape is a hitbox and
which is a hurtbox.

### Level 6 — Vectors and angles (the math of aiming)

**What it is:** a `Vector2` is an arrow: a direction and a length. Aiming, swinging, dashing,
knockback — all vectors.

**Five facts you need:**

1. `b - a` = arrow from `a` to `b`. ("Where is the enemy from me?")
2. `.normalized()` = same direction, length 1. ("Only the direction, please.")
3. `.length()` = distance.
4. `.angle_to()` gives a **signed** angle: + one side, − the other. Use `absf(...)` for "how far off".
5. In Godot 2D, **y goes down**. Up on screen is negative y.

**Read:**
- [Vector math](https://docs.godotengine.org/en/stable/tutorials/math/vector_math.html) — **read fully.** The most useful page for combat.
- [Matrices and transforms](https://docs.godotengine.org/en/stable/tutorials/math/matrices_and_transforms.html) — later; explains `position` vs `global_position`, and rotation of child nodes (our `SwingPivot`).

**You know it when:** you can read `scripts/components/sector_shape.gd` and draw on paper what
shape it makes.

### Level 7 — Resources: data as files

**What it is:** a **Resource** is a file of data (`.tres`). Our weapons are Resources:
`data/weapons/*.tres`. A new weapon = a new file, no new code.

**Example:** to make a slow heavy axe, copy the sword `.tres`, raise `damage` and `windup`.
Nothing else.

**Read:**
- [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)
- [Data preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/data_preferences.html) — later.

**Trap:** a Resource is **shared** by default. If two enemies use the same `.tres` and code
changes `damage` at runtime, *both* change. Ask the AI "is this resource shared?" when it
edits one in code.

**You know it when:** you can make a second weapon by only creating a `.tres` file.

### Level 8 — Visuals: drawing, sprites, animation, tweens

**What it is:** all the ways to put things on screen.

| Tool | Plain meaning | In BossFight |
|---|---|---|
| `_draw()` + `queue_redraw()` | draw shapes by code | debug overlay (F1), telegraph |
| `Sprite2D` | show one picture | `Body`, `Blade` |
| `AnimatedSprite2D` | flip-book of pictures | later, real character art |
| `AnimationPlayer` | animate *any* property on a timeline | later |
| `Tween` | "move this value from A to B over 0.2s" | hit flashes, small effects |
| `@tool` | run the script inside the editor too | so you can *see* sprites while placing them |

**Read:**
- [Custom drawing in 2D](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)
- [2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html)
- [Introduction to animation](https://docs.godotengine.org/en/stable/tutorials/animation/introduction.html)
- [Tween class](https://docs.godotengine.org/en/stable/classes/class_tween.html)
- [Running code in the editor (@tool)](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html)
- Our own: [replacing-art.md](replacing-art.md), [juice-and-vfx.md](../reference/godot/juice-and-vfx.md)

**You know it when:** you can explain why swapping the player's circle for a sprite should only
touch `Visual` (see [replacing-art.md](replacing-art.md)).

### Level 9 — Debugging and testing: see what is really happening

**What it is:** the tools that show you the game's inside while it runs.

| Tool | What it shows | How |
|---|---|---|
| `print()` | a value in the Output panel | add a line, run |
| Debugger → **Remote** tree | the *live* scene tree and values while playing | editor, top of Scene panel, "Remote" |
| Breakpoint | pause the game on one line | click left of a line number |
| Our `F1` / `F2` / `F3` | hitboxes / slow-mo / live tuning | in game |
| Headless check | "does the code even parse?" | `godot --headless --check-only --script <file>` |
| Tests | "does the rule still hold?" | `tools/run_tests.sh` |

**Read:**
- [Overview of debugging tools](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/overview_of_debugging_tools.html)
- [Debugger panel](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html)
- [Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- Our own: [how-to-tune.md](how-to-tune.md)

**You know it when:** the game does something odd, and your first move is F1 + F2 (slow-mo) to
*look*, not asking the AI "fix it".

### Level 10+ — Only when a slice needs it

Do not study these now. Open them the day a feature needs them.

| Topic | Needed for | Read |
|---|---|---|
| UI: `Control` nodes, anchors | HUD, menus, hotbar | [UI index](https://docs.godotengine.org/en/stable/tutorials/ui/index.html), [Size and anchors](https://docs.godotengine.org/en/stable/tutorials/ui/size_and_anchors.html) |
| Autoloads (global nodes) | game-wide state, music | [Singletons (Autoload)](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html) |
| Audio | hit sounds | [Audio index](https://docs.godotengine.org/en/stable/tutorials/audio/index.html) |
| Saving | progress, settings | [Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) |
| Particles | sparks, blood, dust | [2D particles](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html) |
| Camera shake | hit feel | [Camera2D class](https://docs.godotengine.org/en/stable/classes/class_camera2d.html) |
| RL bosses | the boss brain | **not in Godot docs** — [rl-and-onnx.md](../reference/godot/rl-and-onnx.md), [0008](../decision/0008-rl-inference.md) |

---

## 3. How to read a class page (a skill you will use daily)

Every node type has a page in the **Class reference**, e.g.
[Area2D](https://docs.godotengine.org/en/stable/classes/class_area2d.html). The fastest way to
open one: in the editor script window, **Ctrl + click** a type name, or press **F1** and search.

Each page has the same parts:

| Part | Ask it |
|---|---|
| **Inherits** (top line) | "What else can this do?" `Area2D` inherits `CollisionObject2D` → `Node2D` → `Node`. So it also has everything `Node2D` has (position, rotation). |
| **Properties** | "What can I set?" (these show in the Inspector) |
| **Methods** | "What can I ask it to do?" |
| **Signals** | "What does it shout?" |

**Example:** the AI uses `hitbox.monitoring = false`. You don't know that word. Open `Area2D`
→ Properties → `monitoring`: "if true, the area detects bodies or areas entering and exiting."
Now you know: the AI is switching the sword's hit zone off. 30 seconds, no guessing.

---

## 4. Working with the AI on a feature — the loop

This is the part that stops "blind coding". Use it every slice.

### Before: know what you want

1. Write the **feel question** in one line. Example: *"Does the dodge feel like a quick dash?"*
2. Find which **levels** above it touches. Dodge = level 3 (physics process), 5 (body movement),
   6 (direction vector). Spend 10–15 minutes on those pages if they are new to you.

### During: make the AI explain first, then code

Ask for the **plan in Godot words** before any code:

> "Before coding: which nodes, which signals, which @export numbers? Which docs page covers the
> main node you will use?"

If the answer does not make sense to you, ask *"explain like I only know levels 1–5 of
learning-godot-with-ai.md"*. That is not a weak question. It is how you learn.

### After: read the change with this checklist

| Check | Why | Red flag example |
|---|---|---|
| Is every feel number an `@export`? | so you can tune it in F3 | `var speed = 900` hidden inside a function |
| Does combat code call visual code directly? | art swap must not touch combat | `attacker.gd` calling `$Visual/Body.modulate = ...` |
| Long node paths like `get_node("A/B/C")`? | breaks when a node moves | use groups or an exported `NodePath` |
| Is it **Godot 4** code? | AI often mixes in Godot 3 | see table below |
| Did it add F1 / F3 visibility? | CLAUDE.md §7 | new cooldown you cannot see |
| Did it add or run a test? | proof, not "should work" | "I think it works" |

**Godot 3 code the AI sometimes writes by mistake** (it will not work in 4.7):

| Godot 3 (wrong) | Godot 4 (right) |
|---|---|
| `export var x = 1` | `@export var x := 1` |
| `onready var n = $N` | `@onready var n := $N` |
| `yield(obj, "sig")` | `await obj.sig` |
| `connect("hit", self, "_on_hit")` | `hit.connect(_on_hit)` |
| `KinematicBody2D` | `CharacterBody2D` |
| `move_and_slide(velocity)` | set `velocity`, then `move_and_slide()` |
| `setget` | `var x: set = _set_x` / property syntax |

### Then: run it, look at it, judge it

1. The AI runs the headless check and tests (it must show you the output).
2. **You** play it. F1 to see shapes. F2 to slow down. F3 to change numbers.
3. Say what you feel in normal words ("the swing lands late"). Turning that into numbers is the
   AI's job.

---

## 5. Good questions to ask the AI

Short questions that make you learn while you build:

- "Which docs page explains this node?"
- "What would I **see on screen** if this line was wrong?"
- "Why `_physics_process` here and not `_process`?"
- "Who listens to this signal?"
- "Is this number an `@export`? Where do I tune it?"
- "Is this Godot 4.7 syntax? Check the class reference."
- "What happens if the enemy is already inside the hitbox when it turns on?"
- "If I replace the circle with a sprite, which files change?"

---

## 6. Suggested first two weeks

| Day | Do |
|---|---|
| 1 | Level 0: editor tour + start "Dodge the Creeps" |
| 2 | Finish "Dodge the Creeps" (by hand, no AI) |
| 3 | Level 1 + 2: open `player.tscn`, read `weapon_data.gd` and `health.gd` |
| 4 | Level 3 + 4: read `player.gd` and `dodge.gd`; find every `.connect(` |
| 5 | Level 5: play with F1 on; read `hitbox.gd` and `hurtbox.gd` |
| 6 | Level 6: vector math page; read `sector_shape.gd` with paper + pen |
| 7 | Level 7: make a new weapon `.tres` alone, test it in game |
| 8–9 | Level 8: read `weapon_visual.gd`, [replacing-art.md](replacing-art.md) |
| 10 | Level 9: set a breakpoint in `health.gd`, hit the dummy, look at the values |
| 11+ | Build the next slice with the AI, using the loop in section 4 |

---

## See also

- [prototype-v0.md](prototype-v0.md) — what we are building and how it is split up
- [how-to-tune.md](how-to-tune.md) — F1 / F2 / F3 in detail
- [replacing-art.md](replacing-art.md) — how to swap placeholder art
- [docs/reference/godot/](../reference/godot/) — combat patterns, juice, melee, RL notes
- `.claude/memory/godot-gotchas.md` — every Godot trap we have already fallen into
