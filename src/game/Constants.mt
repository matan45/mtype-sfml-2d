// Shared constants: collision categories, faction ids, unit/building specs,
// resource costs, world dimensions. Pure data — no behavior.

class Cat {
    public static function terrain():     int { return 1; }
    public static function unitPlayer():  int { return 2; }
    public static function unitEnemy():   int { return 4; }
    public static function building():    int { return 8; }
    public static function resource():    int { return 16; }
    public static function sensor():      int { return 32; }
    public static function all():         int { return 65535; }
}

class Faction {
    public static function player(): int { return 1; }
    public static function enemy():  int { return 2; }
}

class UnitKind {
    public static function worker(): int { return 1; }
    public static function grunt():  int { return 2; }
}

class BuildingKind {
    public static function base(): int { return 1; }
}

// World is 64 m square centered on origin; tile grid is 1 m, so 64x64 cells.
class GameConst {
    public static function gridSize():    int   { return 64; }
    public static function tileMeters():  float { return 1.0; }
    public static function worldHalf():   float { return 32.0; }

    public static function workerRadius():       float { return 0.4; }
    public static function workerSpeed():        float { return 4.0; }
    public static function workerHp():           float { return 30.0; }
    public static function workerGatherAmount(): int   { return 5; }
    public static function workerGatherTime():   float { return 1.5; }

    public static function gruntRadius():     float { return 0.5; }
    public static function gruntSpeed():      float { return 3.0; }
    public static function gruntHp():         float { return 40.0; }
    public static function gruntDamage():     float { return 8.0; }
    public static function gruntRange():      float { return 1.2; }
    public static function gruntCooldown():   float { return 1.0; }
    public static function gruntSensorPad():  float { return 4.0; }

    public static function baseHalfW():       float { return 2.0; }
    public static function baseHalfH():       float { return 2.0; }
    public static function baseHp():          float { return 500.0; }
    public static function baseRallyDx():     float { return 0.0; }
    public static function baseRallyDy():     float { return 3.0; }

    public static function resourceHalfW():   float { return 1.0; }
    public static function resourceHalfH():   float { return 1.0; }
    public static function resourceStartAmt(): int  { return 1000; }

    public static function workerCost():       int   { return 50; }
    public static function workerBuildTime():  float { return 3.0; }
    public static function startingMinerals(): int   { return 50; }

    public static function fixedDt():    float { return 0.01666667; }
    public static function physSubSteps(): int { return 4; }
    public static function maxFrameDt(): float { return 0.25; }
}
