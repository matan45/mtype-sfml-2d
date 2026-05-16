// Move units toward their current waypoint by setting linearVelocity
// directly. Box2D handles unit-unit collision through filter categories;
// no formal collision-avoidance pass.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Body.mt";

import * from "./Schema.mt";
import * from "./Pathing.mt";

class Steering {
    public static function run(Registry reg, float dt): void {
        string[] need = ["Unit", "PhysicsBody", "MoveOrder"];
        View v = reg.view(need);
        int e = v.next();
        while (e != 0) {
            Unit       u  = (Unit)       reg.get(e, "Unit");
            PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
            MoveOrder   mo = (MoveOrder)   reg.get(e, "MoveOrder");

            Body b = new Body(pb.bodyHandle);
            float[] p = b.position();

            // Resolve current waypoint: either from path if present, else
            // beeline to mo.tx/ty.
            float tx = mo.tx;
            float ty = mo.ty;
            int   advanced = 0;

            PathEntry pe = Pathing::findPath(e);
            if (pe != null) {
                int idx = mo.pathIdx;
                if (idx < 0) { idx = 0; }
                if (idx < pe.count) {
                    tx = pe.xs[idx];
                    ty = pe.ys[idx];
                    float dxw = tx - p[0];
                    float dyw = ty - p[1];
                    if (dxw * dxw + dyw * dyw < 0.36) {
                        idx = idx + 1;
                        advanced = 1;
                        if (idx < pe.count) {
                            tx = pe.xs[idx];
                            ty = pe.ys[idx];
                        } else {
                            tx = mo.tx;
                            ty = mo.ty;
                        }
                    }
                    if (idx != mo.pathIdx) {
                        mo.pathIdx = idx;
                        reg.emplace(e, "MoveOrder", mo);
                    }
                }
            }

            float dx = tx - p[0];
            float dy = ty - p[1];
            float d2 = dx * dx + dy * dy;
            if (d2 < 0.04) {
                // Arrived. Clear order, path, and stop the body.
                b.setLinearVelocity(0.0, 0.0);
                reg.remove(e, "MoveOrder");
                if (reg.has(e, "HasPath")) { reg.remove(e, "HasPath"); }
                Pathing::clearPath(e);
            } else {
                float inv = 1.0 / sqrt(d2);
                float vx = dx * inv * u.speed;
                float vy = dy * inv * u.speed;
                b.setLinearVelocity(vx, vy);
            }

            e = v.next();
        }
        v.destroy();
    }
}
