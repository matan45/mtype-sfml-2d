// Build a frame's worth of WorldSnapshot data from the registry +
// physics. Imports EnTT (which has its own `View` class) — Render.mt
// does NOT, which is why this file exists as the boundary.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Body.mt";

import * from "../game/Constants.mt";
import * from "../render/Snapshots.mt";
import * from "./Schema.mt";

class Sampling {
    public static function refresh(Registry reg, WorldSnapshot snap): void {
        Sampling::collectUnits(reg, snap);
        Sampling::collectBuildings(reg, snap);
        Sampling::collectResources(reg, snap);
        Sampling::collectSelected(reg, snap);
    }

    public static function collectUnits(Registry reg, WorldSnapshot snap): void {
        string[] need = ["Unit", "PhysicsBody"];
        EnttView v = reg.view(need);
        int n = 0;
        int e = v.next();
        while (e != 0) {
            Unit        u  = (Unit)        reg.get(e, "Unit");
            PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
            Body b = new Body(pb.bodyHandle);
            float[] p = b.position();
            if (n < snap.unitX.length) {
                snap.unitX[n]       = p[0];
                snap.unitY[n]       = p[1];
                snap.unitRadius[n]  = u.radius;
                snap.unitFaction[n] = u.faction;
                snap.unitHp[n]      = u.hp;
                snap.unitMaxHp[n]   = u.maxHp;
                snap.unitAttack[n]  = u.attackDamage;
                snap.unitDefense[n] = u.defense;
                n = n + 1;
            }
            e = v.next();
        }
        v.destroy();
        snap.unitCount = n;
    }

    public static function collectBuildings(Registry reg, WorldSnapshot snap): void {
        string[] need = ["Building", "PhysicsBody"];
        EnttView v = reg.view(need);
        int n = 0;
        int e = v.next();
        while (e != 0) {
            Building b = (Building) reg.get(e, "Building");
            PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
            Body bd = new Body(pb.bodyHandle);
            float[] p = bd.position();
            if (n < snap.buildingX.length) {
                float hw = GameConst::commandCenterHalfW();
                float hh = GameConst::commandCenterHalfH();
                if (b.kind == BuildingKind::barracks()) {
                    hw = GameConst::barracksHalfW();
                    hh = GameConst::barracksHalfH();
                } else if (b.kind == BuildingKind::refinery()) {
                    hw = GameConst::refineryHalfW();
                    hh = GameConst::refineryHalfH();
                } else if (b.kind == BuildingKind::commandCenter()) {
                    hw = GameConst::commandCenterHalfW();
                    hh = GameConst::commandCenterHalfH();
                }
                snap.buildingX[n] = p[0];
                snap.buildingY[n] = p[1];
                snap.buildingHw[n] = hw;
                snap.buildingHh[n] = hh;
                snap.buildingFaction[n] = b.faction;
                snap.buildingKind[n] = b.kind;
                snap.buildingHp[n] = b.hp;
                snap.buildingMaxHp[n] = b.maxHp;
                snap.buildingDefense[n] = b.defense;
                if (reg.has(e, "Ghost")) {
                    snap.buildingIsGhost[n] = 1;
                    Construction c = (Construction) reg.get(e, "Construction");
                    float frac = 0.0;
                    if (c.buildTime > 0.0001) { frac = c.progress / c.buildTime; }
                    if (frac < 0.0) { frac = 0.0; }
                    if (frac > 1.0) { frac = 1.0; }
                    snap.buildingProgress[n] = frac;
                } else {
                    snap.buildingIsGhost[n] = 0;
                    snap.buildingProgress[n] = 0.0;
                }
                n = n + 1;
            }
            e = v.next();
        }
        v.destroy();
        snap.buildingCount = n;
    }

    public static function collectResources(Registry reg, WorldSnapshot snap): void {
        string[] need = ["ResourceNode"];
        EnttView v = reg.view(need);
        int n = 0;
        int e = v.next();
        while (e != 0) {
            ResourceNode rn = (ResourceNode) reg.get(e, "ResourceNode");
            if (n < snap.resourceX.length) {
                float hw = GameConst::resourceHalfW();
                float hh = GameConst::resourceHalfH();
                if (rn.kind == ResourceKind::gas()) {
                    hw = GameConst::gasNodeHalfW();
                    hh = GameConst::gasNodeHalfH();
                }
                snap.resourceX[n] = rn.x;
                snap.resourceY[n] = rn.y;
                snap.resourceHw[n] = hw;
                snap.resourceHh[n] = hh;
                snap.resourceKind[n] = rn.kind;
                n = n + 1;
            }
            e = v.next();
        }
        v.destroy();
        snap.resourceCount = n;
    }

    public static function collectSelected(Registry reg, WorldSnapshot snap): void {
        string[] need = ["Selected", "PhysicsBody"];
        EnttView v = reg.view(need);
        int n = 0;
        int e = v.next();
        while (e != 0) {
            PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
            Body b = new Body(pb.bodyHandle);
            float[] p = b.position();
            float radius = 0.5;
            if (reg.has(e, "Unit")) {
                Unit u = (Unit) reg.get(e, "Unit");
                radius = u.radius;
            } else if (reg.has(e, "Building")) {
                Building bld = (Building) reg.get(e, "Building");
                float hw = GameConst::commandCenterHalfW();
                if (bld.kind == BuildingKind::barracks()) { hw = GameConst::barracksHalfW(); }
                else if (bld.kind == BuildingKind::refinery()) { hw = GameConst::refineryHalfW(); }
                radius = hw + 0.1;
            }
            if (n < snap.selectedX.length) {
                snap.selectedX[n] = p[0];
                snap.selectedY[n] = p[1];
                snap.selectedRadius[n] = radius;
                n = n + 1;
            }
            e = v.next();
        }
        v.destroy();
        snap.selectedCount = n;
    }
}
