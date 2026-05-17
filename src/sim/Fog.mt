// Fog of war over the 64x64 tile grid.
//
// State per cell:
//   0 = unexplored (never seen — drawn fully black on top of world)
//   1 = explored   (seen before, currently not in any player unit's sight —
//                    drawn dim/gray on top of world)
//   2 = visible    (currently inside a PlayerControlled unit/building sight)
//
// Each tick: clear all visible cells back to explored, then walk every
// PlayerControlled entity with sightRange > 0 and mark cells within the
// disc as visible. Cells touched for the first time go straight from
// unexplored to visible (and decay to explored on the next tick they're
// out of sight).

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Body.mt";

import * from "../game/Constants.mt";
import * from "./Schema.mt";
import * from "./Pathing.mt";

class Fog {
    // 64*64 = 4096 cells.
    public static int[] state  = new int[4096];
    public static int   inited = 0;

    public static function ensureInit(): void {
        if (Fog::inited == 1) { return; }
        int n = 4096;
        int i = 0;
        while (i < n) { Fog::state[i] = 0; i = i + 1; }
        Fog::inited = 1;
    }

    public static function get(int cx, int cy): int {
        if (cx < 0) { return 0; }
        if (cy < 0) { return 0; }
        int gs = GameConst::gridSize();
        if (cx >= gs) { return 0; }
        if (cy >= gs) { return 0; }
        return Fog::state[cy * gs + cx];
    }

    // World-space helper: state at (x, y).
    public static function getAt(float x, float y): int {
        int cx = Pathing::toCellX(x);
        int cy = Pathing::toCellY(y);
        return Fog::get(cx, cy);
    }

    public static function update(Registry reg): void {
        Fog::ensureInit();
        int gs = GameConst::gridSize();
        int n  = gs * gs;

        // Decay: anything currently visible drops to explored.
        int i = 0;
        while (i < n) {
            if (Fog::state[i] == 2) { Fog::state[i] = 1; }
            i = i + 1;
        }

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
    // visible. Uses square-of-distance to skip a sqrt per cell.
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
                    Fog::state[cy * gs + cx] = 2;
                }
                cx = cx + 1;
            }
            cy = cy + 1;
        }
    }
}
