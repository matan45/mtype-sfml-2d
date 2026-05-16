// Destroy any entity tagged Dead this tick: free its Box2D body (which
// also destroys all attached shapes), drop any visibility-pair entries
// pointing at or from it, clear its cached path, and destroy the entity
// from the registry.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Body.mt";

import * from "../game/Constants.mt";
import * from "./Schema.mt";
import * from "./Events.mt";
import * from "./Pathing.mt";

class Cleanup {
    public static function run(Registry reg, World world): void {
        // Snapshot dead entities into a plain int[] before iterating —
        // destroying entities mid-view would invalidate the cursor.
        string[] need = ["Dead"];
        EnttView v = reg.view(need);
        int[] all = v.entities();
        v.destroy();

        int n = all.length;
        int i = 0;
        while (i < n) {
            int ent = all[i];
            // Free the pathing footprint BEFORE destroying the body so we
            // still have its world position.
            if (reg.has(ent, "Building") && reg.has(ent, "PhysicsBody")) {
                Building bld = (Building) reg.get(ent, "Building");
                PhysicsBody pb = (PhysicsBody) reg.get(ent, "PhysicsBody");
                Body b = new Body(pb.bodyHandle);
                float[] p = b.position();
                float hx = GameConst::buildingHalfExtent(bld.kind);
                Pathing::blockArea(p[0] - hx, p[1] - hx,
                                     p[0] + hx, p[1] + hx, false);
            }
            if (reg.has(ent, "PhysicsBody")) {
                PhysicsBody pb = (PhysicsBody) reg.get(ent, "PhysicsBody");
                Body b = new Body(pb.bodyHandle);
                b.destroy();
            }
            Events::removeAllInvolving(ent);
            Pathing::clearPath(ent);
            reg.destroyEntity(ent);
            i = i + 1;
        }
    }
}
