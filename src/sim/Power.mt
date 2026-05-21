// Derived power budget. Completed player buildings consume/provide power;
// ghosts do not count until construction finishes.

import * from "@mtype-entt/Entt.mt";

import * from "../game/Constants.mt";
import * from "./Schema.mt";

class Power {
    public static function refresh(Registry reg): void {
        int used = 0;
        int cap = 0;

        string[] need = ["Building", "PlayerControlled"];
        EnttView v = reg.view(need);
        int e = v.next();
        while (e != 0) {
            if (!reg.has(e, "Ghost")) {
                Building b = (Building) reg.get(e, "Building");
                cap = cap + Power::providedBy(b.kind);
                used = used + Power::usedBy(b.kind);
            }
            e = v.next();
        }
        v.destroy();

        int low = 0;
        if (used > cap) { low = 1; }
        reg.ctxSetInt("powerUsed", used);
        reg.ctxSetInt("powerCap", cap);
        reg.ctxSetInt("lowPower", low);
    }

    public static function providedBy(int buildingKind): int {
        if (buildingKind == BuildingKind::powerPlant()) {
            return GameConst::powerPlantProvides();
        }
        return 0;
    }

    public static function usedBy(int buildingKind): int {
        if (buildingKind == BuildingKind::commandCenter()) {
            return GameConst::commandCenterPowerUse();
        }
        if (buildingKind == BuildingKind::barracks()) {
            return GameConst::barracksPowerUse();
        }
        if (buildingKind == BuildingKind::refinery()) {
            return GameConst::refineryPowerUse();
        }
        return 0;
    }
}
