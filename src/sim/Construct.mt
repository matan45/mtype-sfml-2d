// Worker construction system. Iterates every Unit with a ConstructOrder,
// walks them to the targeted ghost, and contributes dt to the ghost's
// Construction.progress while in range. Multiple builders stack — each
// contributes its own dt per tick. On completion, hands off to
// Spawn::completeConstruction and drops the order.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Box2D.mt";
import * from "@mtype-box2d/Body.mt";

import * from "../game/Constants.mt";
import * from "./Schema.mt";
import * from "./Spawn.mt";
import * from "./Pathing.mt";

class Construct {
    public static function run(Registry reg, World world, float dt): void {
        string[] need = ["ConstructOrder", "PhysicsBody", "Unit"];
        EnttView v = reg.view(need);
        int[] all = v.entities();
        v.destroy();

        int n = all.length;
        int i = 0;
        while (i < n) {
            int e = all[i];
            i = i + 1;
            if (!reg.valid(e)) { continue; }
            if (!reg.has(e, "ConstructOrder")) { continue; }

            ConstructOrder co = (ConstructOrder) reg.get(e, "ConstructOrder");
            int ghostE = co.targetEntity;

            // Ghost gone or already completed → drop the order.
            if (!reg.valid(ghostE) || !reg.has(ghostE, "Construction")) {
                reg.remove(e, "ConstructOrder");
                continue;
            }

            PhysicsBody pb  = (PhysicsBody) reg.get(e, "PhysicsBody");
            PhysicsBody gpb = (PhysicsBody) reg.get(ghostE, "PhysicsBody");
            Body wb = new Body(pb.bodyHandle);
            Body gb = new Body(gpb.bodyHandle);
            float[] wp = wb.position();
            float[] gp = gb.position();

            float dx = gp[0] - wp[0];
            float dy = gp[1] - wp[1];
            float d2 = dx * dx + dy * dy;
            float prox = GameConst::buildProximity();

            if (d2 <= prox * prox) {
                // Close enough: stop, contribute progress.
                wb.setLinearVelocity(0.0, 0.0);
                if (reg.has(e, "MoveOrder")) {
                    reg.remove(e, "MoveOrder");
                    Pathing::clearPath(e);
                }
                Construction c = (Construction) reg.get(ghostE, "Construction");
                c.progress = c.progress + dt;
                if (c.progress >= c.buildTime) {
                    Spawn::completeConstruction(reg, world, ghostE);
                    reg.remove(e, "ConstructOrder");
                } else {
                    reg.emplace(ghostE, "Construction", c);
                }
            } else {
                // Out of range: walk to the ghost. Re-plan only if existing
                // MoveOrder is stale (target moved or no order yet).
                int needsOrder = 0;
                if (!reg.has(e, "MoveOrder")) { needsOrder = 1; }
                else {
                    MoveOrder cur = (MoveOrder) reg.get(e, "MoveOrder");
                    float ddx = cur.tx - gp[0];
                    float ddy = cur.ty - gp[1];
                    if (ddx * ddx + ddy * ddy > 0.25) { needsOrder = 1; }
                }
                if (needsOrder == 1) {
                    MoveOrder mo = new MoveOrder();
                    mo.tx = gp[0];
                    mo.ty = gp[1];
                    mo.hasPath = 0;
                    mo.pathIdx = 0;
                    reg.emplace(e, "MoveOrder", mo);
                    Pathing::plan(e, world, pb.bodyHandle, gp[0], gp[1]);
                    if (!reg.has(e, "HasPath")) { reg.emplaceTag(e, "HasPath"); }
                }
            }
        }
    }
}
