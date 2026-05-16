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

    // Snapshot selected player units that can receive a move/attack/gather
    // order. Returns an int[] of entity ids.
    public static function selectedUnits(Registry reg): int[] {
        string[] need = ["Selected", "Unit", "PlayerControlled"];
        View v = reg.view(need);
        int[] ents = v.entities();
        v.destroy();
        return ents;
    }

    public static function apply(Registry reg, World world,
                                   RenderWindow win, CameraState cam,
                                   InputState in): void {
        if (!in.rightClickEdge) { return; }
        float[] cw = Selection::cursorWorld(win, cam, in);
        float wx = cw[0];
        float wy = cw[1];

        int enemy = Commands::pickEntity(reg, world, wx, wy, Cat::unitEnemy());
        int mineral = 0;
        if (enemy == 0) {
            mineral = Commands::pickEntity(reg, world, wx, wy, Cat::resource());
        }

        int[] units = Commands::selectedUnits(reg);
        int n = units.length;
        if (n == 0) { return; }

        int baseEntity = reg.ctxGetInt("baseEntity");

        int i = 0;
        while (i < n) {
            int e = units[i];
            Unit u = (Unit) reg.get(e, "Unit");

            // Clear any prior order before issuing a new one.
            if (reg.has(e, "Carrying"))    { reg.remove(e, "Carrying"); }
            if (reg.has(e, "AttackOrder")) { reg.remove(e, "AttackOrder"); }
            if (reg.has(e, "Gathering"))   { reg.remove(e, "Gathering"); }

            PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");

            if (enemy != 0 && u.attackDamage > 0.0) {
                AttackOrder ao = new AttackOrder();
                ao.targetEntity = enemy;
                reg.emplace(e, "AttackOrder", ao);
                Body tb = Commands::bodyOf(reg, enemy);
                if (tb != null) {
                    float[] tp = tb.position();
                    Commands::setMove(reg, e, pb.bodyHandle, tp[0], tp[1], world);
                }
            } else if (mineral != 0 && u.kind == UnitKind::worker()) {
                ResourceNode rn = (ResourceNode) reg.get(mineral, "ResourceNode");
                Carrying c = new Carrying();
                c.amount = 0;
                c.homeBase = baseEntity;
                c.sourceNode = mineral;
                c.gatherLeft = GameConst::workerGatherTime();
                reg.emplace(e, "Carrying", c);
                reg.emplaceTag(e, "Gathering");
                Commands::setMove(reg, e, pb.bodyHandle, rn.x, rn.y, world);
            } else {
                Commands::setMove(reg, e, pb.bodyHandle, wx, wy, world);
            }
            i = i + 1;
        }
    }

    public static function bodyOf(Registry reg, int e): Body {
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
