// Translate right-clicks into orders on every Selected player unit.
// Three intents (in order of priority):
//   1) Right-click on an enemy unit  -> AttackOrder
//   2) Right-click on a mineral pile -> Carrying gather loop
//   3) Right-click anywhere else     -> MoveOrder

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
import * from "./Pathing.mt";

class Commands {
    // Find the first entity under (wx, wy) matching `mask`. Returns 0 if none.
    public static function pickEntity(Registry reg, World world,
                                        float wx, float wy, int mask): int {
        int[] hits = Query::overlapAABB(world,
                                          wx - 0.4, wy - 0.4, wx + 0.4, wy + 0.4,
                                          Cat::all(), mask);
        int n = hits.length;
        int i = 0;
        while (i < n) {
            Shape sh = new Shape(hits[i]);
            int bh = sh.body();
            if (bh != 0) {
                Body b = new Body(bh);
                int e = b.userDataInt();
                if (reg.valid(e)) { return e; }
            }
            i = i + 1;
        }
        return 0;
    }

    // Return the player BaseBuilding (initial Base or completed Command
    // Center) closest to (wx, wy). 0 if none exist.
    public static function findNearestHomeBase(Registry reg, float wx, float wy): int {
        string[] need = ["BaseBuilding", "Building", "PhysicsBody"];
        EnttView v = reg.view(need);
        int best = 0;
        float bestD2 = 1000000000.0;
        int e = v.next();
        while (e != 0) {
            if (!reg.has(e, "Ghost")) {
                PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
                Body b = new Body(pb.bodyHandle);
                float[] p = b.position();
                float dx = p[0] - wx;
                float dy = p[1] - wy;
                float d2 = dx * dx + dy * dy;
                if (d2 < bestD2) { bestD2 = d2; best = e; }
            }
            e = v.next();
        }
        v.destroy();
        return best;
    }

    // Sensor-category AABB pick filtered to entities with the Ghost tag.
    // Necessary because grunt range-sensors also live in Cat::sensor().
    public static function pickGhost(Registry reg, World world,
                                       float wx, float wy): int {
        int[] hits = Query::overlapAABB(world,
                                          wx - 0.4, wy - 0.4, wx + 0.4, wy + 0.4,
                                          Cat::all(), Cat::sensor());
        int n = hits.length;
        int i = 0;
        while (i < n) {
            Shape sh = new Shape(hits[i]);
            int bh = sh.body();
            if (bh != 0) {
                Body b = new Body(bh);
                int e = b.userDataInt();
                if (reg.valid(e) && reg.has(e, "Ghost")) { return e; }
            }
            i = i + 1;
        }
        return 0;
    }

    // Building-category pick filtered to enemy-faction buildings (real,
    // not ghost). Used so a right-click sends grunts to attack hostile
    // structures.
    public static function pickEnemyBuilding(Registry reg, World world,
                                               float wx, float wy): int {
        int[] hits = Query::overlapAABB(world,
                                          wx - 0.4, wy - 0.4, wx + 0.4, wy + 0.4,
                                          Cat::all(), Cat::building());
        int n = hits.length;
        int i = 0;
        while (i < n) {
            Shape sh = new Shape(hits[i]);
            int bh = sh.body();
            if (bh != 0) {
                Body b = new Body(bh);
                int e = b.userDataInt();
                if (reg.valid(e) && reg.has(e, "Building") && !reg.has(e, "Ghost")) {
                    Building bld = (Building) reg.get(e, "Building");
                    if (bld.faction == Faction::enemy()) { return e; }
                }
            }
            i = i + 1;
        }
        return 0;
    }

    // Building-category pick filtered to entities with a Refinery component
    // (i.e. completed refineries, not other buildings).
    public static function pickRefinery(Registry reg, World world,
                                          float wx, float wy): int {
        int[] hits = Query::overlapAABB(world,
                                          wx - 0.4, wy - 0.4, wx + 0.4, wy + 0.4,
                                          Cat::all(), Cat::building());
        int n = hits.length;
        int i = 0;
        while (i < n) {
            Shape sh = new Shape(hits[i]);
            int bh = sh.body();
            if (bh != 0) {
                Body b = new Body(bh);
                int e = b.userDataInt();
                if (reg.valid(e) && reg.has(e, "Refinery")) { return e; }
            }
            i = i + 1;
        }
        return 0;
    }

    // Snapshot selected player units that can receive a move/attack/gather
    // order. Returns an int[] of entity ids.
    public static function selectedUnits(Registry reg): int[] {
        string[] need = ["Selected", "Unit", "PlayerControlled"];
        EnttView v = reg.view(need);
        int[] ents = v.entities();
        v.destroy();
        return ents;
    }

    public static function apply(Registry reg, World world,
                                   RenderWindow win, CameraState cam,
                                   InputState in): void {
        if (in.stopPressed) {
            Commands::stopSelected(reg);
            return;
        }

        if (in.commandMode == CommandMode::attackMove()) {
            if (in.rightClickEdge) {
                in.commandMode = CommandMode::normal();
            } else if (in.leftDownEdge) {
                float[] aw = Selection::cursorWorld(win, cam, in);
                Commands::issueAttackMove(reg, world, aw[0], aw[1]);
                in.commandMode = CommandMode::normal();
                in.leftDownEdge = false;
                in.leftUpEdge = false;
                in.leftHeld = false;
                return;
            } else {
                return;
            }
        }

        if (!in.rightClickEdge) { return; }
        float[] cw = Selection::cursorWorld(win, cam, in);
        float wx = cw[0];
        float wy = cw[1];

        int enemy = Commands::pickEntity(reg, world, wx, wy, Cat::unitEnemy());
        int enemyBldg = 0;
        int ghost = 0;
        int refinery = 0;
        int mineral = 0;
        if (enemy == 0) {
            enemyBldg = Commands::pickEnemyBuilding(reg, world, wx, wy);
            if (enemyBldg == 0) {
                ghost = Commands::pickGhost(reg, world, wx, wy);
                if (ghost == 0) {
                    refinery = Commands::pickRefinery(reg, world, wx, wy);
                    if (refinery == 0) {
                        mineral = Commands::pickEntity(reg, world, wx, wy, Cat::resource());
                        // Disqualify gas geysers — workers can only harvest gas
                        // through a refinery, not the bare geyser.
                        if (mineral != 0 && reg.has(mineral, "GasGeyser")) {
                            mineral = 0;
                        }
                    }
                }
            }
        }

        int[] units = Commands::selectedUnits(reg);
        int n = units.length;
        if (n == 0) { return; }

        int i = 0;
        while (i < n) {
            int e = units[i];
            Unit u = (Unit) reg.get(e, "Unit");

            // Clear any prior order before issuing a new one.
            if (reg.has(e, "Carrying"))        { reg.remove(e, "Carrying"); }
            if (reg.has(e, "AttackOrder"))     { reg.remove(e, "AttackOrder"); }
            if (reg.has(e, "AttackMoveOrder")) { reg.remove(e, "AttackMoveOrder"); }
            if (reg.has(e, "ConstructOrder"))  { reg.remove(e, "ConstructOrder"); }
            if (reg.has(e, "Gathering"))       { reg.remove(e, "Gathering"); }

            PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");

            if (enemy != 0 && u.attackDamage > 0.0) {
                AttackOrder ao = new AttackOrder();
                ao.targetEntity = enemy;
                reg.emplace(e, "AttackOrder", ao);
                Body? tb = Commands::bodyOf(reg, enemy);
                if (tb != null) {
                    float[] tp = tb.position();
                    Commands::setMove(reg, e, pb.bodyHandle, tp[0], tp[1], world);
                }
            } else if (enemyBldg != 0 && u.attackDamage > 0.0) {
                AttackOrder ao = new AttackOrder();
                ao.targetEntity = enemyBldg;
                reg.emplace(e, "AttackOrder", ao);
                Body? tb = Commands::bodyOf(reg, enemyBldg);
                if (tb != null) {
                    float[] tp = tb.position();
                    Commands::setMove(reg, e, pb.bodyHandle, tp[0], tp[1], world);
                }
            } else if (ghost != 0 && u.kind == UnitKind::worker()) {
                ConstructOrder co = new ConstructOrder();
                co.targetEntity = ghost;
                reg.emplace(e, "ConstructOrder", co);
                Body? gb = Commands::bodyOf(reg, ghost);
                if (gb != null) {
                    float[] gp = gb.position();
                    Commands::setMove(reg, e, pb.bodyHandle, gp[0], gp[1], world);
                }
            } else if (refinery != 0 && u.kind == UnitKind::worker()) {
                Body wb = new Body(pb.bodyHandle);
                float[] wp = wb.position();
                int homeE = Commands::findNearestHomeBase(reg, wp[0], wp[1]);
                if (homeE == 0) {
                    // No Command Center to drop off at — refuse the order
                    // and just walk to the cursor.
                    Commands::setMove(reg, e, pb.bodyHandle, wx, wy, world);
                } else {
                    Carrying c = new Carrying();
                    c.amount = 0;
                    c.homeBase = homeE;
                    c.sourceNode = refinery;
                    c.gatherLeft = GameConst::workerGatherTime();
                    c.kind = ResourceKind::gas();
                    reg.emplace(e, "Carrying", c);
                    reg.emplaceTag(e, "Gathering");
                    Body? rb = Commands::bodyOf(reg, refinery);
                    if (rb != null) {
                        float[] rp = rb.position();
                        Commands::setMove(reg, e, pb.bodyHandle, rp[0], rp[1], world);
                    }
                }
            } else if (mineral != 0 && u.kind == UnitKind::worker()) {
                Body wb = new Body(pb.bodyHandle);
                float[] wp = wb.position();
                int homeE = Commands::findNearestHomeBase(reg, wp[0], wp[1]);
                if (homeE == 0) {
                    Commands::setMove(reg, e, pb.bodyHandle, wx, wy, world);
                } else {
                    ResourceNode rn = (ResourceNode) reg.get(mineral, "ResourceNode");
                    Carrying c = new Carrying();
                    c.amount = 0;
                    c.homeBase = homeE;
                    c.sourceNode = mineral;
                    c.gatherLeft = GameConst::workerGatherTime();
                    c.kind = ResourceKind::minerals();
                    reg.emplace(e, "Carrying", c);
                    reg.emplaceTag(e, "Gathering");
                    Commands::setMove(reg, e, pb.bodyHandle, rn.x, rn.y, world);
                }
            } else {
                Commands::setMove(reg, e, pb.bodyHandle, wx, wy, world);
            }
            i = i + 1;
        }
    }

    public static function issueAttackMove(Registry reg, World world,
                                            float tx, float ty): void {
        int[] units = Commands::selectedUnits(reg);
        int n = units.length;
        int i = 0;
        while (i < n) {
            int e = units[i];
            Unit u = (Unit) reg.get(e, "Unit");
            if (u.attackDamage > 0.0 && reg.has(e, "PhysicsBody")) {
                Commands::clearOrders(reg, e, false);
                AttackMoveOrder amo = new AttackMoveOrder();
                amo.tx = tx;
                amo.ty = ty;
                reg.emplace(e, "AttackMoveOrder", amo);
                PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
                Commands::setMove(reg, e, pb.bodyHandle, tx, ty, world);
            }
            i = i + 1;
        }
    }

    public static function stopSelected(Registry reg): void {
        int[] units = Commands::selectedUnits(reg);
        int n = units.length;
        int i = 0;
        while (i < n) {
            int e = units[i];
            Commands::clearOrders(reg, e, true);
            if (reg.has(e, "PhysicsBody")) {
                PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
                Body b = new Body(pb.bodyHandle);
                b.setLinearVelocity(0.0, 0.0);
            }
            i = i + 1;
        }
    }

    public static function clearOrders(Registry reg, int e, bool clearMove): void {
        if (reg.has(e, "Carrying"))        { reg.remove(e, "Carrying"); }
        if (reg.has(e, "AttackOrder"))     { reg.remove(e, "AttackOrder"); }
        if (reg.has(e, "AttackMoveOrder")) { reg.remove(e, "AttackMoveOrder"); }
        if (reg.has(e, "ConstructOrder"))  { reg.remove(e, "ConstructOrder"); }
        if (reg.has(e, "Gathering"))       { reg.remove(e, "Gathering"); }
        if (clearMove && reg.has(e, "MoveOrder")) { reg.remove(e, "MoveOrder"); }
        if (clearMove && reg.has(e, "HasPath")) { reg.remove(e, "HasPath"); }
        if (clearMove) { Pathing::clearPath(e); }
    }

    public static function bodyOf(Registry reg, int e): Body? {
        if (!reg.valid(e)) { return null; }
        if (!reg.has(e, "PhysicsBody")) { return null; }
        PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
        return new Body(pb.bodyHandle);
    }

    public static function setMove(Registry reg, int e, int bodyHandle,
                                     float tx, float ty, World world): void {
        MoveOrder mo = new MoveOrder();
        mo.tx = tx;
        mo.ty = ty;
        mo.hasPath = 0;
        mo.pathIdx = 0;
        reg.emplace(e, "MoveOrder", mo);
        Pathing::plan(e, world, bodyHandle, tx, ty);
        if (!reg.has(e, "HasPath")) { reg.emplaceTag(e, "HasPath"); }
    }
}
