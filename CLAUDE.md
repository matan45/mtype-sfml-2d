# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

`sfml-2d` is a fresh-scaffold **mType** project (the mType language lives at `C:\matan\mType`). The whole project today is one near-empty entry point at `src/run/main.mt`. Its purpose is to combine three native mType runtime plugins:

- **mtype-sfml** — SFML 3 rendering / windowing / audio / ImGui (`mt_modules/@mtype-sfml/mt/lib/{Sfml,Graphics,Audio,ImGui,System}.mt`)
- **mtype-box2d** — Box2D v3 physics (`mt_modules/@mtype-box2d/mt/lib/{Box2D,Body,Shape,Joint,Query,DebugDraw}.mt`)
- **mtype-entt** — EnTT ECS (`mt_modules/@mtype-entt/mt/lib/Entt.mt`)

…on top of the **mTypeLib** standard library (`mt_modules/@mTypeLib/{core,math,net,mtest}/`).

`sfml-2d.mtproj` is the manifest; `mtproj.lock` pins versions; `mt_modules/` is the local install dir (gitignored, populated by `mtpm install`); `build/` holds compiled bytecode (`.mtc`, also gitignored).

## Toolchain

Neither `mType.exe` nor `mtpm.exe` is on `PATH`. Always invoke them by absolute path:

- Compiler / runtime: `C:\matan\mType\bin\mType\Release\x64\mType.exe`
- Package manager: `C:\matan\mType\bin\mtpm\Release\x64\mtpm.exe`

## Common commands

Run them from the project root (`C:\matan\sfml-2d`).

```powershell
# Install/update dependencies declared in sfml-2d.mtproj → mt_modules/
& 'C:\matan\mType\bin\mtpm\Release\x64\mtpm.exe' install

# Run a single .mt file directly (compile-in-memory + execute)
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

## Entry point convention

`@EntryPoint` marks the class whose `public static function main(string[] args): void` is invoked. There must be exactly one in the project. The current `src/run/main.mt` is the stub; new gameplay code should be added in `src/` and imported from there (the project's `<Include>` glob is `**/*.mt`).
