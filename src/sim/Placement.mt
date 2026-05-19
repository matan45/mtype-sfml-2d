// Building placement state and per-frame update. Runs at variable-dt,
// immediately after Input::pump and BEFORE Selection::update so it can
// swallow the LMB/RMB edge before selection / commands consume them.
//
// Refinery placement snaps to the nearest free gas geyser within
// refinerySnapRadius. Barracks placement validates "no overlap with
// existing buildings or resource piles".
//
// On confirm: deduct cost, spawn the ghost, auto-assign the nearest
// idle player worker as the builder.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Box2D.mt";
import * from "@mtype-box2d/Body.mt";
import * from "@mtype-box2d/Shape.mt";
import * from "@mtype-box2d/Query.mt";

import * from "../game/Constants.mt";
import * from "../input/Input.mt";
import * from "../input/Selection.mt";
import * from "../render/CameraCtrl.mt";

import * from "./Schema.mt";
import * from "./Spawn.mt";
import * from "./Pathing.mt";

class PlacementState {
    public bool  active;
    public int   kind;
    public bool  validPos;
    public float snapX;
    public float snapY;
    public int   targetGeyser;

    public constructor() {
        this.active = false;
        this.kind = 0;
        this.validPos = false;
        this.snapX = 0.0;
        this.snapY = 0.0;
        this.targetGeyser = 0;
    }

    public function start(int k): void {
        this.active = true;
        this.kind = k;
        this.validPos = false;
        this.snapX = 0.0;
        this.snapY = 0.0;
        this.targetGeyser = 0;
    }

    public function cancel(): void {
        this.active = false;
        this.kind = 0;
        this.validPos = false;
        this.targetGeyser = 0;
    }
}

class Placement {
    public static function update(Registry reg, World world,
                                    RenderWindow win, CameraState cam,
                                    InputState in, PlacementState pls): void {
        if (!pls.active) { return; }

        float[] cw = Selection::cursorWorld(win, cam, in);
        float wx = cw[0];
        float wy = cw[1];

        if (pls.kind == BuildingKind::refinery()) {
            int gE = Placement::findFreeGeyserNear(reg, world, wx, wy,
                                                     GameConst::refinerySnapRadius());
            if (gE != 0) {
                ResourceNode rn = (ResourceNode) reg.get(gE, "ResourceNode");
                pls.snapX = rn.x;
                pls.snapY = rn.y;
                pls.validPos = true;
                pls.targetGeyser = gE;
            } else {
                pls.snapX = wx;
                pls.snapY = wy;
                pls.validPos = false;
                pls.targetGeyser = 0;
            }
        } else {
            float hw = GameConst::barracksHalfW();
            float hh = GameConst::barracksHalfH();
            if (pls.kind == BuildingKind::commandCenter()) {
                hw = GameConst::commandCenterHalfW();
                hh = GameConst::commandCenterHalfH();
            } else if (pls.kind == BuildingKind::powerPlant()) {
                hw = GameConst::powerPlantHalfW();
                hh = GameConst::powerPlantHalfH();
            }
            pls.snapX = wx;
            pls.snapY = wy;
            pls.validPos = Placement::overlapsNothing(world, wx, wy, hw, hh);
            pls.targetGeyser = 0;
        }

        if (in.leftDownEdge && pls.validPos) {
            int cost = Placement::costOf(pls.kind);
            int minerals = reg.ctxGetInt("minerals");
            if (minerals >= cost) {
                reg.ctxSetInt("minerals", minerals - cost);
                int ghostE = 0;
                if (pls.kind == BuildingKind::barracks()) {
                    ghostE = Spawn::barracksGhost(reg, world, pls.snapX, pls.snapY);
                } else if (pls.kind == BuildingKind::commandCenter()) {
                    ghostE = Spawn::commandCenterGhost(reg, world, pls.snapX, pls.snapY);
                } else if (pls.kind == BuildingKind::powerPlant()) {
                    ghostE = Spawn::powerPlantGhost(reg, world, pls.snapX, pls.snapY);
                } else {
                    ghostE = Spawn::refineryGhost(reg, world, pls.snapX, pls.snapY,
                                                    pls.targetGeyser);
                }
                if (ghostE != 0) {
                    Placement::autoAssignBuilder(reg, world, ghostE,
                                                   pls.snapX, pls.snapY);
                }
            }
            pls.cancel();
            in.leftDownEdge = false;
        } else if (in.rightClickEdge) {
            pls.cancel();
            in.rightClickEdge = false;
        }
    }

    public static function costOf(int kind): int {
        if (kind == BuildingKind::barracks())      { return GameConst::barracksCost(); }
        if (kind == BuildingKind::refinery())      { return GameConst::refineryCost(); }
        if (kind == BuildingKind::commandCenter()) { return GameConst::commandCenterCost(); }
        if (kind == BuildingKind::powerPlant())    { return GameConst::powerPlantCost(); }
        return 0;
    }

    // AABB query around cursor for resource bodies. Returns the entity id
    // of a gas geyser that has no Refinery (component) or refinery ghost
    // already assigned to it. 0 if none found.
    public static function findFreeGeyserNear(Registry reg, World world,
                                                float wx, float wy, float r): int {
        int[] hits = Query::overlapAABB(world, wx - r, wy - r, wx + r, wy + r,
                                          Cat::all(), Cat::resource());
        int n = hits.length;
        int i = 0;
        while (i < n) {
            Shape sh = new Shape(hits[i]);
            int bh = sh.body();
            if (bh != 0) {
                Body b = new Body(bh);
                int e = b.userDataInt();
                if (reg.valid(e) && reg.has(e, "GasGeyser")) {
                    if (!Placement::isGeyserTaken(reg, e)) { return e; }
                }
            }
            i = i + 1;
        }
        return 0;
    }

    public static function isGeyserTaken(Registry reg, int geyserE): bool {
        // Completed refineries.
        string[] needR = ["Refinery"];
        EnttView vR = reg.view(needR);
        int er = vR.next();
        while (er != 0) {
            Refinery rf = (Refinery) reg.get(er, "Refinery");
            if (rf.geyserEntity == geyserE) {
                vR.destroy();
                return true;
            }
            er = vR.next();
        }
        vR.destroy();

        // Refinery ghosts in progress.
        string[] needC = ["Construction"];
        EnttView vC = reg.view(needC);
        int ec = vC.next();
        while (ec != 0) {
            Construction c = (Construction) reg.get(ec, "Construction");
            if (c.buildingKind == BuildingKind::refinery() && c.geyserEntity == geyserE) {
                vC.destroy();
                return true;
            }
            ec = vC.next();
        }
        vC.destroy();
        return false;
    }

    // True iff the footprint (wx±hw, wy±hh) has no existing buildings or
    // resource piles in it. Used for barracks validation.
    public static function overlapsNothing(World world, float wx, float wy,
                                             float hw, float hh): bool {
        int[] hits = Query::overlapAABB(world,
                                          wx - hw, wy - hh, wx + hw, wy + hh,
                                          Cat::all(), Cat::building() | Cat::resource());
        return hits.length == 0;
    }

    // Pick the builder: prefer the closest currently-Selected player Worker;
    // if none are selected, fall back to the closest player Worker overall.
    // Emplace a ConstructOrder on it. No-op if no worker exists.
    public static function autoAssignBuilder(Registry reg, World world,
                                               int ghostE, float gx, float gy): void {
        // Pass 1: scan Selected + Worker.
        string[] needSel = ["Selected", "Unit", "PhysicsBody", "PlayerControlled", "Worker"];
        EnttView vs = reg.view(needSel);
        int best = 0;
        float bestD2 = 1000000000.0;
        int e = vs.next();
        while (e != 0) {
            PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
            Body b = new Body(pb.bodyHandle);
            float[] p = b.position();
            float dx = p[0] - gx;
            float dy = p[1] - gy;
            float d2 = dx * dx + dy * dy;
            if (d2 < bestD2) { bestD2 = d2; best = e; }
            e = vs.next();
        }
        vs.destroy();

        // Pass 2 (only if nothing selected): any player Worker.
        if (best == 0) {
            string[] needAny = ["Unit", "PhysicsBody", "PlayerControlled", "Worker"];
            EnttView va = reg.view(needAny);
            int ea = va.next();
            while (ea != 0) {
                PhysicsBody pb = (PhysicsBody) reg.get(ea, "PhysicsBody");
                Body b = new Body(pb.bodyHandle);
                float[] p = b.position();
                float dx = p[0] - gx;
                float dy = p[1] - gy;
                float d2 = dx * dx + dy * dy;
                if (d2 < bestD2) { bestD2 = d2; best = ea; }
                ea = va.next();
            }
            va.destroy();
        }

        if (best == 0) { return; }

        // Clear conflicting orders so the worker abandons what it's doing
        // and commits to building.
        if (reg.has(best, "Carrying"))     { reg.remove(best, "Carrying"); }
        if (reg.has(best, "AttackOrder"))  { reg.remove(best, "AttackOrder"); }
        if (reg.has(best, "AttackMoveOrder")) { reg.remove(best, "AttackMoveOrder"); }
        if (reg.has(best, "Gathering"))    { reg.remove(best, "Gathering"); }

        ConstructOrder co = new ConstructOrder();
        co.targetEntity = ghostE;
        reg.emplace(best, "ConstructOrder", co);

        PhysicsBody bp = (PhysicsBody) reg.get(best, "PhysicsBody");
        MoveOrder mo = new MoveOrder();
        mo.tx = gx;
        mo.ty = gy;
        mo.hasPath = 0;
        mo.pathIdx = 0;
        reg.emplace(best, "MoveOrder", mo);
        Pathing::plan(best, world, bp.bodyHandle, gx, gy);
        if (!reg.has(best, "HasPath")) { reg.emplaceTag(best, "HasPath"); }
    }
}
