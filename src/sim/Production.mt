// Building production. Each base with queueLen > 0 ticks buildLeft; when
// it hits zero, spawn a worker at its rally point and decrement the queue.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Box2D.mt";

import * from "../game/Constants.mt";
import * from "./Schema.mt";
import * from "./Spawn.mt";

class Production {
    public static function run(Registry reg, World world, float dt): void {
        string[] need = ["Building"];
        EnttView v = reg.view(need);
        int e = v.next();
        while (e != 0) {
            Building b = (Building) reg.get(e, "Building");
            if (b.queueLen > 0) {
                b.buildLeft = b.buildLeft - dt;
                if (b.buildLeft <= 0.0) {
                    b.queueLen = b.queueLen - 1;
                    if (b.queueLen > 0) {
                        b.buildLeft = GameConst::workerBuildTime();
                    } else {
                        b.buildLeft = 0.0;
                    }
                    Spawn::worker(reg, world, b.rallyX, b.rallyY);
                }
                reg.emplace(e, "Building", b);
            }
            e = v.next();
        }
        v.destroy();
    }

    // Called from the HUD when the user clicks Train Worker on a selected
    // base. Deducts cost up front, queues a worker, kicks off the timer
    // if this is the first item in the queue.
    public static function tryQueueWorker(Registry reg, int baseEntity): bool {
        if (!reg.valid(baseEntity)) { return false; }
        if (!reg.has(baseEntity, "Building")) { return false; }
        int minerals = reg.ctxGetInt("minerals");
        if (minerals < GameConst::workerCost()) { return false; }
        Building b = (Building) reg.get(baseEntity, "Building");
        if (b.queueLen >= 5) { return false; }
        reg.ctxSetInt("minerals", minerals - GameConst::workerCost());
        if (b.queueLen == 0) { b.buildLeft = GameConst::workerBuildTime(); }
        b.queueLen = b.queueLen + 1;
        reg.emplace(baseEntity, "Building", b);
        return true;
    }
}
