// Building production. Each base with queueLen > 0 ticks buildLeft; when
// it hits zero, spawn a worker at its rally point and decrement the queue.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Box2D.mt";

import * from "../game/Constants.mt";
import * from "../audio/Audio.mt";
import * from "./Schema.mt";
import * from "./Spawn.mt";

class Production {
    public static function run(Registry reg, World world, float dt): void {
        if (reg.ctxGetInt("lowPower") == 1) { return; }

        string[] need = ["Building"];
        EnttView v = reg.view(need);
        int e = v.next();
        while (e != 0) {
            if (reg.has(e, "Ghost")) { e = v.next(); continue; }
            Building b = (Building) reg.get(e, "Building");
            if (b.queueLen > 0) {
                b.buildLeft = b.buildLeft - dt;
                if (b.buildLeft <= 0.0) {
                    b.queueLen = b.queueLen - 1;
                    float nextBuildTime = Production::buildTimeFor(b.kind);
                    if (b.queueLen > 0) {
                        b.buildLeft = nextBuildTime;
                    } else {
                        b.buildLeft = 0.0;
                    }
                    if (b.kind == BuildingKind::barracks()) {
                        Spawn::playerGrunt(reg, world, b.rallyX, b.rallyY);
                    } else {
                        Spawn::worker(reg, world, b.rallyX, b.rallyY);
                    }
                    Audio::playChord();
                }
                reg.emplace(e, "Building", b);
            }
            e = v.next();
        }
        v.destroy();
    }

    // Cost in minerals for the unit a given building produces.
    public static function costFor(int buildingKind): int {
        if (buildingKind == BuildingKind::barracks()) { return GameConst::gruntCost(); }
        return GameConst::workerCost();
    }

    public static function buildTimeFor(int buildingKind): float {
        if (buildingKind == BuildingKind::barracks()) { return GameConst::gruntBuildTime(); }
        return GameConst::workerBuildTime();
    }

    // Queue one unit at this building. Caller already knows the building
    // entity (HUD computes it from selection). Deducts cost up front.
    public static function tryQueueUnit(Registry reg, int buildingEntity): bool {
        if (!reg.valid(buildingEntity)) { return false; }
        if (!reg.has(buildingEntity, "Building")) { return false; }
        if (reg.has(buildingEntity, "Ghost")) { return false; }
        Building b = (Building) reg.get(buildingEntity, "Building");
        if (reg.ctxGetInt("lowPower") == 1) { return false; }
        int cost = Production::costFor(b.kind);
        int minerals = reg.ctxGetInt("minerals");
        if (minerals < cost) { return false; }
        if (b.queueLen >= 5) { return false; }
        reg.ctxSetInt("minerals", minerals - cost);
        if (b.queueLen == 0) { b.buildLeft = Production::buildTimeFor(b.kind); }
        b.queueLen = b.queueLen + 1;
        reg.emplace(buildingEntity, "Building", b);
        return true;
    }

}
