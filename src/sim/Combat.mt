// Two concerns merged into one file because both consume per-unit
// AttackOrder/Carrying state and advance cooldowns:
//   - Combat: combatants (enemies) deal damage to AttackOrder targets in
//     range; targets that drop to 0 hp get a Dead tag.
//   - Gather: workers with Carrying tick a small state machine between
//     a ResourceNode (sourceNode) and a base (homeBase), updating the
//     unit's MoveOrder each time the goal flips.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Body.mt";

import * from "../game/Constants.mt";
import * from "./Schema.mt";
import * from "./Events.mt";
import * from "./Pathing.mt";

class Combat {
    // ---- Combat: enemies attacking player units --------------------
    public static function run(Registry reg, World world, float dt): void {
        string[] need = ["Unit", "PhysicsBody"];
        View v = reg.view(need);
        int e = v.next();
        while (e != 0) {
            Unit u = (Unit) reg.get(e, "Unit");
            if (u.attackDamage > 0.0) {
                if (u.cooldownLeft > 0.0) {
                    u.cooldownLeft = u.cooldownLeft - dt;
                    if (u.cooldownLeft < 0.0) { u.cooldownLeft = 0.0; }
                    reg.emplace(e, "Unit", u);
                }

                int target = 0;
                if (reg.has(e, "AttackOrder")) {
                    AttackOrder ao = (AttackOrder) reg.get(e, "AttackOrder");
                    if (reg.valid(ao.targetEntity) && !reg.has(ao.targetEntity, "Dead")) {
                        target = ao.targetEntity;
                    } else {
                        reg.remove(e, "AttackOrder");
                    }
                }
                if (target == 0) {
                    int seen = Events::anyTargetOf(e);
                    if (seen != 0 && reg.valid(seen) && !reg.has(seen, "Dead")) {
                        AttackOrder ao = new AttackOrder();
                        ao.targetEntity = seen;
                        reg.emplace(e, "AttackOrder", ao);
                        target = seen;
                    }
                }

                if (target != 0) {
                    Combat::pursueAndStrike(reg, world, e, u, target, dt);
                }
            }
            e = v.next();
        }
        v.destroy();
    }

    public static function pursueAndStrike(Registry reg, World world,
                                            int attacker, Unit u, int target, float dt): void {
        PhysicsBody apb = (PhysicsBody) reg.get(attacker, "PhysicsBody");
        PhysicsBody tpb = (PhysicsBody) reg.get(target, "PhysicsBody");
        Body ab = new Body(apb.bodyHandle);
        Body tb = new Body(tpb.bodyHandle);
        float[] ap = ab.position();
        float[] tp = tb.position();
        float dx = tp[0] - ap[0];
        float dy = tp[1] - ap[1];
        float d2 = dx * dx + dy * dy;
        float reach = u.attackRange + u.radius;
        if (d2 <= reach * reach) {
            ab.setLinearVelocity(0.0, 0.0);
            if (reg.has(attacker, "MoveOrder")) {
                reg.remove(attacker, "MoveOrder");
                Pathing::clearPath(attacker);
            }
            if (u.cooldownLeft <= 0.0) {
                Unit tu = (Unit) reg.get(target, "Unit");
                tu.hp = tu.hp - u.attackDamage;
                if (tu.hp <= 0.0) {
                    tu.hp = 0.0;
                    if (!reg.has(target, "Dead")) { reg.emplaceTag(target, "Dead"); }
                }
                reg.emplace(target, "Unit", tu);
                u.cooldownLeft = u.attackCooldown;
                reg.emplace(attacker, "Unit", u);
            }
        } else {
            // Out of range: refresh MoveOrder to chase target. Only re-plan
            // when the target has noticeably moved or we don't have one.
            int needsOrder = 0;
            if (!reg.has(attacker, "MoveOrder")) { needsOrder = 1; }
            else {
                MoveOrder mo = (MoveOrder) reg.get(attacker, "MoveOrder");
                float ddx = mo.tx - tp[0];
                float ddy = mo.ty - tp[1];
                if (ddx * ddx + ddy * ddy > 4.0) { needsOrder = 1; }
            }
            if (needsOrder == 1) {
                MoveOrder mo = new MoveOrder();
                mo.tx = tp[0];
                mo.ty = tp[1];
                mo.hasPath = 0;
                mo.pathIdx = 0;
                reg.emplace(attacker, "MoveOrder", mo);
                Pathing::plan(attacker, world, apb.bodyHandle, tp[0], tp[1]);
                if (!reg.has(attacker, "HasPath")) { reg.emplaceTag(attacker, "HasPath"); }
            }
        }
    }
}

class Gather {
    // ---- Worker gather/deposit state machine ------------------------
    public static function run(Registry reg, World world, float dt): void {
        string[] need = ["Carrying", "PhysicsBody"];
        View v = reg.view(need);
        int e = v.next();
        while (e != 0) {
            Carrying c = (Carrying) reg.get(e, "Carrying");
            PhysicsBody pb = (PhysicsBody) reg.get(e, "PhysicsBody");
            Body b = new Body(pb.bodyHandle);
            float[] p = b.position();

            if (c.amount == 0) {
                // Heading to the mineral pile.
                if (!reg.valid(c.sourceNode)) { reg.remove(e, "Carrying"); e = v.next(); continue; }
                ResourceNode rn = (ResourceNode) reg.get(c.sourceNode, "ResourceNode");
                float dx = rn.x - p[0];
                float dy = rn.y - p[1];
                float d2 = dx * dx + dy * dy;
                if (d2 <= 2.25) {
                    b.setLinearVelocity(0.0, 0.0);
                    if (reg.has(e, "MoveOrder")) {
                        reg.remove(e, "MoveOrder");
                        Pathing::clearPath(e);
                    }
                    c.gatherLeft = c.gatherLeft - dt;
                    if (c.gatherLeft <= 0.0) {
                        int take = GameConst::workerGatherAmount();
                        if (rn.amount < take) { take = rn.amount; }
                        c.amount = take;
                        rn.amount = rn.amount - take;
                        c.gatherLeft = GameConst::workerGatherTime();
                        reg.emplace(c.sourceNode, "ResourceNode", rn);
                        Gather::orderToward(reg, world, e, pb.bodyHandle, p, c.homeBase);
                    }
                    reg.emplace(e, "Carrying", c);
                } else {
                    Gather::orderToward(reg, world, e, pb.bodyHandle, p, c.sourceNode);
                }
            } else {
                // Carrying ore — head to the base to drop it off.
                if (!reg.valid(c.homeBase)) { reg.remove(e, "Carrying"); e = v.next(); continue; }
                Building bld = (Building) reg.get(c.homeBase, "Building");
                float dx = bld.rallyX - p[0];
                float dy = bld.rallyY - p[1];
                float d2 = dx * dx + dy * dy;
                if (d2 <= 6.25) {
                    int cur = reg.ctxGetInt("minerals");
                    reg.ctxSetInt("minerals", cur + c.amount);
                    c.amount = 0;
                    reg.emplace(e, "Carrying", c);
                    b.setLinearVelocity(0.0, 0.0);
                    if (reg.has(e, "MoveOrder")) {
                        reg.remove(e, "MoveOrder");
                        Pathing::clearPath(e);
                    }
                    Gather::orderToward(reg, world, e, pb.bodyHandle, p, c.sourceNode);
                } else {
                    Gather::orderToward(reg, world, e, pb.bodyHandle, p, c.homeBase);
                }
            }
            e = v.next();
        }
        v.destroy();
    }

    // Ensure a MoveOrder + path exists for `e` aimed at the entity
    // `targetEntity`. Picks the entity's own position field.
    public static function orderToward(Registry reg, World world,
                                         int e, int bodyHandle,
                                         float[] selfPos, int targetEntity): void {
        if (!reg.valid(targetEntity)) { return; }
        float tx = 0.0;
        float ty = 0.0;
        if (reg.has(targetEntity, "ResourceNode")) {
            ResourceNode rn = (ResourceNode) reg.get(targetEntity, "ResourceNode");
            tx = rn.x;
            ty = rn.y;
        } else if (reg.has(targetEntity, "Building")) {
            Building bld = (Building) reg.get(targetEntity, "Building");
            tx = bld.rallyX;
            ty = bld.rallyY;
        }
        int needsOrder = 0;
        if (!reg.has(e, "MoveOrder")) { needsOrder = 1; }
        else {
            MoveOrder cur = (MoveOrder) reg.get(e, "MoveOrder");
            float ddx = cur.tx - tx;
            float ddy = cur.ty - ty;
            if (ddx * ddx + ddy * ddy > 0.25) { needsOrder = 1; }
        }
        if (needsOrder == 1) {
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
}
