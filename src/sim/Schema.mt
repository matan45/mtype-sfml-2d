// ECS component & tag classes plus the one-shot registerAll() that wires
// every one of them into the registry at startup.
//
// IMPORTANT: per Entt.mt's contract, get() synthesizes return objects via
// the host without calling the mType-side constructor. So component
// classes are pure POD — public fields and no constructor logic.

import * from "@mtype-entt/Entt.mt";

class PhysicsBody {
    public int bodyHandle;
}

class Unit {
    public int   kind;
    public int   faction;
    public float hp;
    public float maxHp;
    public float radius;
    public float speed;
    public float attackRange;
    public float attackDamage;
    public float attackCooldown;
    public float cooldownLeft;
}

class Selectable {
    public float radius;
}

class MoveOrder {
    public float tx;
    public float ty;
    public int   hasPath;
    public int   pathIdx;
}

class AttackOrder {
    public int targetEntity;
}

class Building {
    public int   kind;
    public int   faction;
    public float hp;
    public float maxHp;
    public int   producing;
    public float buildLeft;
    public int   queueLen;
    public float rallyX;
    public float rallyY;
}

class ResourceNode {
    public int   amount;
    public float x;
    public float y;
}

class Carrying {
    public int   amount;
    public int   homeBase;
    public int   sourceNode;
    public float gatherLeft;
}

class RangeSensor {
    public int sensorShapeHandle;
}

class Schema {
    public static function registerAll(Registry reg): void {
        // ---- payload components ----
        string[] f1 = ["bodyHandle"];
        int[]    t1 = [Entts::fieldInt()];
        reg.registerComponent("PhysicsBody", "PhysicsBody", f1, t1);

        string[] fU = ["kind","faction","hp","maxHp","radius","speed",
                       "attackRange","attackDamage","attackCooldown","cooldownLeft"];
        int[]    tU = [Entts::fieldInt(), Entts::fieldInt(),
                       Entts::fieldFloat(), Entts::fieldFloat(),
                       Entts::fieldFloat(), Entts::fieldFloat(),
                       Entts::fieldFloat(), Entts::fieldFloat(),
                       Entts::fieldFloat(), Entts::fieldFloat()];
        reg.registerComponent("Unit", "Unit", fU, tU);

        string[] fS = ["radius"];
        int[]    tS = [Entts::fieldFloat()];
        reg.registerComponent("Selectable", "Selectable", fS, tS);

        string[] fM = ["tx","ty","hasPath","pathIdx"];
        int[]    tM = [Entts::fieldFloat(), Entts::fieldFloat(),
                       Entts::fieldInt(),   Entts::fieldInt()];
        reg.registerComponent("MoveOrder", "MoveOrder", fM, tM);

        string[] fA = ["targetEntity"];
        int[]    tA = [Entts::fieldInt()];
        reg.registerComponent("AttackOrder", "AttackOrder", fA, tA);

        string[] fB = ["kind","faction","hp","maxHp","producing","buildLeft",
                       "queueLen","rallyX","rallyY"];
        int[]    tB = [Entts::fieldInt(),   Entts::fieldInt(),
                       Entts::fieldFloat(), Entts::fieldFloat(),
                       Entts::fieldInt(),   Entts::fieldFloat(),
                       Entts::fieldInt(),   Entts::fieldFloat(), Entts::fieldFloat()];
        reg.registerComponent("Building", "Building", fB, tB);

        string[] fR = ["amount","x","y"];
        int[]    tR = [Entts::fieldInt(), Entts::fieldFloat(), Entts::fieldFloat()];
        reg.registerComponent("ResourceNode", "ResourceNode", fR, tR);

        string[] fC = ["amount","homeBase","sourceNode","gatherLeft"];
        int[]    tC = [Entts::fieldInt(), Entts::fieldInt(),
                       Entts::fieldInt(), Entts::fieldFloat()];
        reg.registerComponent("Carrying", "Carrying", fC, tC);

        string[] fRS = ["sensorShapeHandle"];
        int[]    tRS = [Entts::fieldInt()];
        reg.registerComponent("RangeSensor", "RangeSensor", fRS, tRS);

        // ---- tag components ----
        reg.registerTag("Selected");
        reg.registerTag("PlayerControlled");
        reg.registerTag("Enemy");
        reg.registerTag("Dead");
        reg.registerTag("Worker");
        reg.registerTag("Grunt");
        reg.registerTag("BaseBuilding");
        reg.registerTag("HasPath");
        reg.registerTag("Gathering");

        // ---- ctx vars ----
        reg.ctxSetInt("minerals", 50);
    }
}
