# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

`sfml-2d` is a **2D classic-base-builder RTS** in progress, written in **mType** (the mType language lives at `C:\matan\mType`). It combines three native mType runtime plugins on top of the mTypeLib stdlib:

- **mtype-sfml** — SFML 3 rendering / windowing / audio / ImGui (`mt_modules/@mtype-sfml/mt/lib/{Sfml,Graphics,Audio,ImGui,System}.mt`)
- **mtype-box2d** — Box2D v3 physics (`mt_modules/@mtype-box2d/mt/lib/{Box2D,Body,Shape,Joint,Query,DebugDraw}.mt`)
- **mtype-entt** — EnTT ECS (`mt_modules/@mtype-entt/mt/lib/Entt.mt`)
- **mTypeLib** — stdlib: `Vec2f`, collections, math, JSON, networking, `mtest` (`mt_modules/@mTypeLib/{core,math,net,mtest}/`)

`sfml-2d.mtproj` is the manifest; `mtproj.lock` pins versions; `mt_modules/` is the local install dir (gitignored, populated by `mtpm install`); `build/` holds compiled bytecode (`.mtc`, gitignored).

## Game architecture (MVP)

The game lives entirely under `src/`. Flat file layout, one verb per file — no Engine / Application class:

```
src/run/main.mt              @EntryPoint, plugin load/unload, fixed-timestep main loop
src/game/Constants.mt        collision bit masks, faction ids, unit specs, costs
src/sim/Schema.mt            register every ECS component + tag (PhysicsBody, Unit, MoveOrder, …)
src/sim/Spawn.mt             spawn worker/grunt/base/resource — pairs Box2D body + ECS entity
src/sim/Commands.mt          right-click -> MoveOrder/AttackOrder on selected units
src/sim/Pathing.mt           128×128 grid (2 m cells), A* with LoS smoothing, side-map of waypoint arrays
src/sim/Steering.mt          waypoint -> body.setLinearVelocity (no avoidance — Box2D handles)
src/sim/Combat.mt            Combat class (enemy AI + damage), Gather class (worker minerals)
src/sim/Events.mt            drain world.nextSensorBegin/End -> (attacker, target) pair list
src/sim/Production.mt        building queue tick + worker spawn at rally point
src/sim/Cleanup.mt           destroy bodies + entities tagged Dead
src/sim/Sampling.mt          extract WorldSnapshot from registry each frame (boundary class)
src/sim/Fog.mt               128×128 fog-of-war state (unexplored/explored/visible); update() walks PlayerControlled
src/input/Input.mt           SFML event pump + ImGui forward + InputState (edge events)
src/input/Selection.mt       drag-box state machine, AABB picking, Selected tag
src/render/CameraCtrl.mt     WASD pan + wheel zoom on a SFML View (CameraState mirror)
src/render/Snapshots.mt      WorldSnapshot POD (parallel float[] arrays of unit/building/etc data + fogStateF float[])
src/render/Render.mt         draw entities, selection rings, HP bars, debug overlay, calls FogShader
src/render/FogShader.mt      World-space fog overlay; gs×gs RGBA8 Texture updated via bulk FFI, drawn as one Sprite
src/render/Minimap.mt        bottom-right screen-space minimap + click-to-pan camera
src/render/Hud.mt            ImGui panels: minerals, FPS, single-unit HP/ATK/DEF, build buttons
```

Tick order inside `while (acc >= fixedDt)`: Commands → Selection → Combat → Gather → Steering → `world.step` → Events::drain → Production → Cleanup → Fog::update. Variable-dt (once per frame): camera update → Sampling → ImGui frame → Render → Minimap → ImGui::render → present. `Minimap::handleClick` runs before Selection/Commands so a click in the minimap pans the camera instead of issuing a world command.

### Cross-cutting conventions

- **Position lives on the Box2D body.** There is no Transform component; render-time reads `body.position()` via Sampling. Cached transforms drift.
- **Entity ↔ body link** is `body.setUserDataInt(entityId)`. Physics events recover the entity via `shape.body() -> Body.userDataInt()`. This is the *only* cross-link.
- **Component classes are POD.** EnTT plugin's `get()` synthesizes return objects via the host; the mType constructor body is NOT invoked. Always plain public fields.
- **No HashMap in our code.** mTypeLib's HashMap works (we patched its imports), but path/sensor side-maps use fixed-cap parallel arrays — simpler and zero allocations on the hot path.
- **Lazy init for plugin-dependent statics.** Class-load-time static initializers that call SFML/Box2D/EnTT natives crash with `Function not found: __native__…` because plugins aren't loaded yet. Defer to first use (see `Input::ensureReady`, `Render::ensurePool`, `FogShader::ensureReady`).
- **Custom-batch SFML draws desync the render-state cache.** `Draw::vertexArray` and `DrawShader::sprite` leave SFML's internal cache out of sync with the real GL state; mixing them in a frame with default `Draw::rect` / `Draw::circle` / ImGui causes ghosting — the next default draw partially misses the back buffer and shows the previous frame's pixels at the old position. Fix: call `Camera::resetGLStates(win)` once after the custom draw (see `FogShader::drawWorld`). Or avoid the cache path entirely by sticking to default-state primitives (the minimap fog uses N small `Draw::rect` calls per supercell instead of one `Draw::vertexArray`).
- **Fog of war is grid-based, 3-state.** `Fog::state[gridSize*gridSize]` holds `0=unexplored, 1=explored, 2=visible`. Each fixed tick: decay visible→explored, then re-reveal disks around every `PlayerControlled` Unit/Building with `sightRange > 0`. `Sampling::collectFog` mirrors the state into the snapshot as a single `float[]` (used directly as a GLSL uniform array, and cast to int at the handful of cell-state lookup sites in renderer/minimap). World fog draws as a single sf::Sprite whose Texture is bulk-updated each frame from `snap.fogStateF` via `Texture::updateFromFogState` (one FFI call; the per-pixel encode runs in C++ inside the `mtype-sfml` plugin and ends with one `sf::Texture::update`). One default-state draw → no SFML cache-desync, ghosting-free at any grid size. The minimap fog still uses per-supercell `Draw::rect` (16×16, ≤256/frame) because the data path is different (screen-space, mixed with the camera viewport wireframe). Earlier attempts at finer world fog (32×32+ rects, or a `uniform float fog[N]` shader) hit one of two SFML-3 limitations: the custom-shader path desyncs the render-state cache (drag-box / ImGui ghost), and large same-shape rect batches do too (probably internal vertex-array batching). The texture approach sidesteps both. We previously rendered the world fog with a single `DrawShader::sprite`, but the custom-shader path desyncs SFML's render-state cache and `RenderWindow::resetGLStates` did not reliably close the gap — drag-box / ImGui / minimap ghosted. Sticking to default-state primitives avoids the issue entirely.

## Toolchain

Neither `mType.exe` nor `mtpm.exe` is on `PATH`. Always invoke them by absolute path:

- Compiler / runtime: `C:\matan\mType\bin\mType\Release\x64\mType.exe`
- Package manager: `C:\matan\mType\bin\mtpm\Release\x64\mtpm.exe`

## Common commands

Run them from the project root (`C:\matan\sfml-2d`).

```powershell
# Install/update dependencies declared in sfml-2d.mtproj → mt_modules/
& 'C:\matan\mType\bin\mtpm\Release\x64\mtpm.exe' install

# Run the game directly (compile-in-memory + execute)
& 'C:\matan\mType\bin\mType\Release\x64\mType.exe' src\run\main.mt

# Build the whole project to bytecode under build/ (.mtc per source file)
& 'C:\matan\mType\bin\mType\Release\x64\mType.exe' --build

# Run already-compiled bytecode
& 'C:\matan\mType\bin\mType\Release\x64\mType.exe' --run-cached build\src\run\main.mtc

# Remove the build/ output
& 'C:\matan\mType\bin\mType\Release\x64\mType.exe' --clean

# Inspect dependency graph / detect cycles
& 'C:\matan\mType\bin\mType\Release\x64\mType.exe' --deps
& 'C:\matan\mType\bin\mType\Release\x64\mType.exe' --deps --cycles

# Useful diagnostic flags
#   --debug       run with breakpoints/stepping
#   --no-jit      disable JIT (JIT is on by default)
#   --gc-stats    print GC stats after run
#   --profile     light profiler; --profile=full for call graph + opcodes
```

There is no separate `lint` or `test` step wired up for this project. The mType stdlib ships its own `mtest` framework (`@mTypeLib/mtest/`); to add tests, create `.mt` files using `@Test` / `@BeforeAll` etc. and run them with `mType.exe <file>`.

## How the native plugins work (important)

The SFML / Box2D / EnTT bindings are **runtime plugins**, not statically linked. Any script that uses them must load the DLL by path before calling the wrapper classes, e.g.:

```mtype
__plugin_load("mt_modules/@mtype-sfml/mt/mtype_sfml.dll");
__plugin_load("mt_modules/@mtype-box2d/mt/mtype_b2d.dll");
__plugin_load("mt_modules/@mtype-entt/mt/mtype_entt.dll");
```

The paths are relative to the **working directory** when `mType.exe` runs. The SFML plugin also depends on the `sfml-*-3.dll` files that sit next to it in `mt_modules/@mtype-sfml/mt/`; keep them together.

Each binding follows a builder pattern with explicit `.destroy()` on def objects, e.g. Box2D:

```mtype
BodyDef bd = new BodyDef();
bd.setType(BodyType::dynamicBody()).setPosition(0.0, -5.0);
Body b = Bodies::create(world, bd);
bd.destroy();
```

The plugins' `mt/demo/*.mt` directories are the most reliable, up-to-date usage references — read those before guessing API shape.

## Import paths

The project's `<Include>` glob is `**/*.mt`. Cross-package imports use `@<package>/<path-within-source>`. Each `mt_modules/@<pkg>/mtpkg.json` declares its `source` root; the import path is relative to that root.

- `@mTypeLib`'s source root is the package root, so: `import * from "@mTypeLib/core/collections/ArrayList.mt";`
- `@mtype-sfml`'s source root is `mt/lib`, so: `import * from "@mtype-sfml/Sfml.mt";` (NOT `@mtype-sfml/mt/lib/Sfml.mt` — that double-prefixes).
- `@mtype-entt`'s source root is `mt/lib`: `import * from "@mtype-entt/Entt.mt";`
- `@mtype-box2d`'s source root is `mt/lib`: `import * from "@mtype-box2d/Box2D.mt";`

Same-package imports use relative paths (`./Foo.mt`, `../bar/Baz.mt`).

## Name collisions across bindings

mType does not namespace by import — a duplicate class name across two imported files is a hard `Duplicate class declaration` error. Known conflicts already resolved:

- `class View` previously existed in both `@mtype-entt/Entt.mt` and `@mtype-sfml/Graphics.mt`. EnTT's was renamed to **`EnttView`** locally; the entt demos under `mt_modules/@mtype-entt/mt/demo/` were updated to match. Use `EnttView` for query results, `View` for SFML cameras.
- ImGui's `Font` was previously renamed to `ImGuiFont` upstream for the same reason.

## Entry point convention

`@EntryPoint` marks the class whose `public static function main(string[] args): void` is invoked. There must be exactly one in the project. Our entry is `src/run/main.mt`; new gameplay code should be added under `src/` and imported from there.

## Verification (manual)

```powershell
& 'C:\matan\mType\bin\mType\Release\x64\mType.exe' src\run\main.mt
```

You should see a 1280×720 window with: a blue Command Center + 4 workers near origin (each with a green HP bar above), a teal mineral pile to the right, two red grunts further right (red HP bars). Most of the map is covered in black/dim fog; only a small visible disc around the player's units & CC is clear. A 200×200 minimap sits in the bottom-right showing the same fog, dots for units/buildings/resources, and a white wireframe of the camera viewport — left-click anywhere in it to pan. Drag-box selects workers (green rings); right-click empty ground moves them; right-click the mineral starts a gather loop; right-click an enemy attacks. Selecting a single unit shows an HP/ATK/DEF block in the Selection HUD panel. Damage applies an armor curve: `max(0.5, attacker.attackDamage - target.defense)`. F1 toggles Box2D debug overlay; selecting the base shows a "Train Worker [50 min]" button; Esc closes.

## Bindings: known issues we've fixed locally

The `@mtype-sfml` plugin source lives at `C:\matan\mtype-sfml`. Two fixes were made there during this project and require the DLL to be rebuilt + copied over `mt_modules/@mtype-sfml/mt/mtype_sfml.dll`:

- `readFloatArray` in `src/GraphicsBindings.cpp` was passing `nullptr` instead of `ctx` to `g_host->arrayGet(...)` — a 0xC0000005 access violation on the first element. All four `Shader::setUniformArray` / `setMat3` / `setMat4` / `setVec4Array` callsites are affected; the helper now takes and forwards `MTypeContext* ctx`.
- A new native `__native__sfml_window_reset_gl_states` was added and exposed as `Camera::resetGLStates(win)` for the cache-desync fix described in the conventions section above.
