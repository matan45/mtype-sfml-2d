// Sensor event drain. Each tick:
//   1) Pull every world.nextSensorBegin/End pair.
//   2) For each pair, walk shape -> body -> userDataInt to recover
//      attacker + target entity ids.
//   3) Maintain a flat list of (attackerEntity, targetEntity) pairs.
//      Combat reads this list to pick its current target.

import * from "@mtype-box2d/Box2D.mt";
import * from "@mtype-box2d/Body.mt";
import * from "@mtype-box2d/Shape.mt";

class Events {
    // Parallel-array side-map of (attacker, target) pairs. Capacity is
    // intentionally fixed; ~30 units * a few visible targets each fits
    // comfortably under 256.
    public static int   cap       = 256;
    public static int[] attackers = new int[256];
    public static int[] targets   = new int[256];
    public static int   pairLen   = 0;

    // Resolve a shape handle to the entity id stored in its body's userDataInt.
    public static function shapeToEntity(int shapeHandle): int {
        Shape sh = new Shape(shapeHandle);
        int bh = sh.body();
        if (bh == 0) { return 0; }
        Body b = new Body(bh);
        return b.userDataInt();
    }

    public static function addPair(int attacker, int target): void {
        if (attacker == 0) { return; }
        if (target == 0) { return; }
        int n = Events::pairLen;
        int i = 0;
        while (i < n) {
            if (Events::attackers[i] == attacker && Events::targets[i] == target) { return; }
            i = i + 1;
        }
        if (n >= Events::cap) { return; }
        Events::attackers[n] = attacker;
        Events::targets[n]   = target;
        Events::pairLen = n + 1;
    }

    public static function removePair(int attacker, int target): void {
        int n = Events::pairLen;
        int i = 0;
        while (i < n) {
            if (Events::attackers[i] == attacker && Events::targets[i] == target) {
                Events::attackers[i] = Events::attackers[n - 1];
                Events::targets[i]   = Events::targets[n - 1];
                Events::pairLen = n - 1;
                return;
            }
            i = i + 1;
        }
    }

    public static function removeAllInvolving(int entity): void {
        int n = Events::pairLen;
        int i = 0;
        while (i < n) {
            if (Events::attackers[i] == entity || Events::targets[i] == entity) {
                Events::attackers[i] = Events::attackers[n - 1];
                Events::targets[i]   = Events::targets[n - 1];
                n = n - 1;
            } else {
                i = i + 1;
            }
        }
        Events::pairLen = n;
    }

    // Find any visible target for `attacker`. Returns 0 if none.
    public static function anyTargetOf(int attacker): int {
        int n = Events::pairLen;
        int i = 0;
        while (i < n) {
            if (Events::attackers[i] == attacker) { return Events::targets[i]; }
            i = i + 1;
        }
        return 0;
    }

    public static function drain(World world): void {
        int[] b = world.nextSensorBegin();
        while (b.length > 0) {
            int sensorShape  = b[0];
            int visitorShape = b[1];
            int attacker = Events::shapeToEntity(sensorShape);
            int target   = Events::shapeToEntity(visitorShape);
            Events::addPair(attacker, target);
            b = world.nextSensorBegin();
        }
        int[] e = world.nextSensorEnd();
        while (e.length > 0) {
            int sensorShape  = e[0];
            int visitorShape = e[1];
            int attacker = Events::shapeToEntity(sensorShape);
            int target   = Events::shapeToEntity(visitorShape);
            Events::removePair(attacker, target);
            e = world.nextSensorEnd();
        }
        // Drain contact begin/end/hit and body-move buffers so they don't
        // pile up — we don't currently consume them.
        int[] cb = world.nextContactBegin();
        while (cb.length > 0) { cb = world.nextContactBegin(); }
        int[] ce = world.nextContactEnd();
        while (ce.length > 0) { ce = world.nextContactEnd(); }
        float[] ch = world.nextContactHit();
        while (ch.length > 0) { ch = world.nextContactHit(); }
        float[] bm = world.nextBodyMove();
        while (bm.length > 0) { bm = world.nextBodyMove(); }
    }
}
