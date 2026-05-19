// Fog of war over the 128x128 tile grid.
//
// State per cell:
//   0 = unexplored (never seen — drawn fully black on top of world)
//   1 = explored   (seen before, currently not in any player unit's sight —
//                    drawn dim/gray on top of world)
//   2 = visible    (currently inside a PlayerControlled unit/building sight)
//
// Each tick: clear all currently-visible cells back to explored, then walk
// every PlayerControlled entity with sightRange > 0 and mark cells within
// the disc as visible. Cells touched for the first time go straight from
// unexplored to visible (and decay to explored on the next tick they're
// out of sight).
//
// Storage notes:
//   - `state` is float[] (not int[]) so the renderer can hand the same
//     buffer straight to the GLSL uniform-array upload — no per-frame
//     int->float copy in Sampling::collectFog.
//   - Decay walks a `visible` index list (cells flipped to 2 last tick)
//     instead of scanning all 16384 cells.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Body.mt";

import * from "../game/Constants.mt";
import * from "./Schema.mt";
import * from "./Pathing.mt";

class Fog {
    // 128*128 = 16384 cells. Stored as float so the shader upload can
    // reference the same buffer without an int->float copy.
    public static float[] state  = new float[16384];
    public static int     inited = 0;

    // Indices of cells flipped to visible (2) during the current tick.
    // Capped at the full grid size as a worst-case; in practice this
    // list holds the sum of sight-disc areas (a few hundred cells).
    public static int[] visible    = new int[16384];
    public static int   visibleLen = 0;

    // Indices of cells whose state changed since the renderer last
    // drained this list (drained by Sampling::collectFog each frame).
    // Lets the renderer setPixel only what changed instead of all 16384
    // cells. Worst-case capped at the grid size.
    public static int[] dirty    = new int[16384];
    public static int   dirtyLen = 0;

    public static function ensureInit(): void {
        if (Fog::inited == 1) { return; }
        int n = 16384;
        int i = 0;
        while (i < n) { Fog::state[i] = 0.0; i = i + 1; }
        Fog::visibleLen = 0;
        Fog::inited = 1;
    }

    public static function get(int cx, int cy): int {
        if (cx < 0) { return 0; }
        if (cy < 0) { return 0; }
        int gs = GameConst::gridSize();
        if (cx >= gs) { return 0; }
        if (cy >= gs) { return 0; }
        return (int)Fog::state[cy * gs + cx];
    }

    // World-space helper: state at (x, y).
    public static function getAt(float x, float y): int {
        int cx = Pathing::toCellX(x);
        int cy = Pathing::toCellY(y);
        return Fog::get(cx, cy);
    }

    public static function update(Registry reg): void {
        Fog::ensureInit();

        // Decay: cells we flipped to visible last tick drop back to explored.
        // No need to scan the whole grid — those cells are exactly the ones
        // in the `visible` list. revealDisc below will repopulate it. Each
        // decayed cell is also appended to `dirty` so the renderer can
        // setPixel only what changed.
        int vn = Fog::visibleLen;
        int i = 0;
        while (i < vn) {
            int idx = Fog::visible[i];
            Fog::state[idx] = 1.0;
            Fog::dirty[Fog::dirtyLen] = idx;
            Fog::dirtyLen = Fog::dirtyLen + 1;
            i = i + 1;
        }
        Fog::visibleLen = 0;

        // Reveal: PlayerControlled units.
        string[] needU = ["Unit", "PhysicsBody", "PlayerControlled"];
        EnttView vU = reg.view(needU);
        int e = vU.next();
        while (e != 0) {
            Unit u = (Unit) reg.get(e, "Unit");
            if (u.sightRange > 0.0) {
                PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
                Body b = new Body(pb.bodyHandle);
                float[] p = b.position();
                Fog::revealDisc(p[0], p[1], u.sightRange);
            }
            e = vU.next();
        }
        vU.destroy();

        // Reveal: PlayerControlled buildings (skip ghosts — they're invisible
        // until promotion, and their sightRange is 0 anyway).
        string[] needB = ["Building", "PhysicsBody", "PlayerControlled"];
        EnttView vB = reg.view(needB);
        e = vB.next();
        while (e != 0) {
            Building bl = (Building) reg.get(e, "Building");
            if (bl.sightRange > 0.0) {
                PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
                Body b = new Body(pb.bodyHandle);
                float[] p = b.position();
                Fog::revealDisc(p[0], p[1], bl.sightRange);
            }
            e = vB.next();
        }
        vB.destroy();
    }

    // Mark every cell whose center is within `r` meters of (wx, wy) as
    // visible. Appends each newly-flipped index to the `visible` list so
    // next tick's decay can find it without a full grid scan. Skips cells
    // already marked visible this tick (avoids duplicate entries when two
    // entities' sight discs overlap).
    public static function revealDisc(float wx, float wy, float r): void {
        int gs = GameConst::gridSize();
        int cx0 = Pathing::toCellX(wx - r);
        int cy0 = Pathing::toCellY(wy - r);
        int cx1 = Pathing::toCellX(wx + r);
        int cy1 = Pathing::toCellY(wy + r);
        if (cx0 < 0)  { cx0 = 0; }
        if (cy0 < 0)  { cy0 = 0; }
        if (cx1 >= gs) { cx1 = gs - 1; }
        if (cy1 >= gs) { cy1 = gs - 1; }
        float r2 = r * r;
        int cy = cy0;
        while (cy <= cy1) {
            float ccy = Pathing::fromCellY(cy);
            int cx = cx0;
            while (cx <= cx1) {
                float ccx = Pathing::fromCellX(cx);
                float dx = ccx - wx;
                float dy = ccy - wy;
                if (dx * dx + dy * dy <= r2) {
                    int idx = cy * gs + cx;
                    if (Fog::state[idx] != 2.0) {
                        Fog::state[idx] = 2.0;
                        Fog::visible[Fog::visibleLen] = idx;
                        Fog::visibleLen = Fog::visibleLen + 1;
                        Fog::dirty[Fog::dirtyLen] = idx;
                        Fog::dirtyLen = Fog::dirtyLen + 1;
                    }
                }
                cx = cx + 1;
            }
            cy = cy + 1;
        }
    }
}
