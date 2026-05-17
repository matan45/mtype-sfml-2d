// Entity-and-body factories. Each function creates a Box2D body, attaches
// the right collision shape, registers the entity, emplaces components,
// and wires the body's userDataInt to the entity id so physics events
// can be mapped back to ECS.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Box2D.mt";
import * from "@mtype-box2d/Body.mt";
import * from "@mtype-box2d/Shape.mt";

import * from "../game/Constants.mt";
import * from "../audio/Audio.mt";
import * from "./Schema.mt";
import * from "./Pathing.mt";

class Spawn {
    // Create a player worker at (x, y). Dynamic body, circle hard shape,
    // no sensor (workers don't auto-attack).
    public static function worker(Registry reg, World world, float x, float y): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::dynamicBody());
        bd.setPosition(x, y);
        bd.setFixedRotation(true);
        bd.setLinearDamping(8.0);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setDensity(1.0);
        sd.setFriction(0.3);
        sd.setFilter(Cat::unitPlayer(), Cat::unitMask(), 0);
        Shape sh = Shapes::createCircle(b, sd, GameConst::workerRadius(), 0.0, 0.0);
        sd.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        Unit u = new Unit();
        u.kind = UnitKind::worker();
        u.faction = Faction::player();
        u.hp = GameConst::workerHp();
        u.maxHp = GameConst::workerHp();
        u.radius = GameConst::workerRadius();
        u.speed = GameConst::workerSpeed();
        u.attackRange = 0.0;
        u.attackDamage = 0.0;
        u.attackCooldown = 0.0;
        u.defense = GameConst::workerDefense();
        u.sightRange = GameConst::workerSight();
        u.cooldownLeft = 0.0;
        reg.emplace(e, "Unit", u);

        Selectable sel = new Selectable();
        sel.radius = GameConst::workerRadius() + 0.3;
        reg.emplace(e, "Selectable", sel);

        reg.emplaceTag(e, "PlayerControlled");
        reg.emplaceTag(e, "Worker");
        return e;
    }

    // Create a PLAYER grunt at (x, y). Same shape & combat stats as the
    // enemy grunt, but PlayerControlled + Selectable, and its sensor scans
    // for enemies instead of players.
    public static function playerGrunt(Registry reg, World world, float x, float y): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::dynamicBody());
        bd.setPosition(x, y);
        bd.setFixedRotation(true);
        bd.setLinearDamping(8.0);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setDensity(1.2);
        sd.setFriction(0.3);
        sd.setFilter(Cat::unitPlayer(), Cat::unitMask(), 0);
        Shape sh = Shapes::createCircle(b, sd, GameConst::gruntRadius(), 0.0, 0.0);
        sd.destroy();

        ShapeDef sdS = new ShapeDef();
        sdS.setDensity(0.0);
        sdS.setIsSensor(true);
        sdS.enableSensorEvents(true);
        int sensMaskP = Cat::unitEnemy() | Cat::building();
        sdS.setFilter(Cat::sensor(), sensMaskP, 0);
        Shape sens = Shapes::createCircle(b, sdS,
                                           GameConst::gruntRange() + GameConst::gruntSensorPad(),
                                           0.0, 0.0);
        sdS.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        Unit u = new Unit();
        u.kind = UnitKind::grunt();
        u.faction = Faction::player();
        u.hp = GameConst::gruntHp();
        u.maxHp = GameConst::gruntHp();
        u.radius = GameConst::gruntRadius();
        u.speed = GameConst::gruntSpeed();
        u.attackRange = GameConst::gruntRange();
        u.attackDamage = GameConst::gruntDamage();
        u.attackCooldown = GameConst::gruntCooldown();
        u.defense = GameConst::gruntDefense();
        u.sightRange = GameConst::gruntSight();
        u.cooldownLeft = 0.0;
        reg.emplace(e, "Unit", u);

        Selectable sel = new Selectable();
        sel.radius = GameConst::gruntRadius() + 0.3;
        reg.emplace(e, "Selectable", sel);

        RangeSensor rs = new RangeSensor();
        rs.sensorShapeHandle = sens.handle;
        reg.emplace(e, "RangeSensor", rs);

        reg.emplaceTag(e, "PlayerControlled");
        reg.emplaceTag(e, "Grunt");
        return e;
    }

    // Create an enemy grunt at (x, y). Dynamic body + circle hard shape +
    // larger circle sensor for target acquisition.
    public static function grunt(Registry reg, World world, float x, float y): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::dynamicBody());
        bd.setPosition(x, y);
        bd.setFixedRotation(true);
        bd.setLinearDamping(8.0);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setDensity(1.2);
        sd.setFriction(0.3);
        sd.setFilter(Cat::unitEnemy(), Cat::unitMask(), 0);
        Shape sh = Shapes::createCircle(b, sd, GameConst::gruntRadius(), 0.0, 0.0);
        sd.destroy();

        ShapeDef sdS = new ShapeDef();
        sdS.setDensity(0.0);
        sdS.setIsSensor(true);
        sdS.enableSensorEvents(true);
        int sensMaskE = Cat::unitPlayer() | Cat::building();
        sdS.setFilter(Cat::sensor(), sensMaskE, 0);
        Shape sens = Shapes::createCircle(b, sdS,
                                           GameConst::gruntRange() + GameConst::gruntSensorPad(),
                                           0.0, 0.0);
        sdS.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        Unit u = new Unit();
        u.kind = UnitKind::grunt();
        u.faction = Faction::enemy();
        u.hp = GameConst::gruntHp();
        u.maxHp = GameConst::gruntHp();
        u.radius = GameConst::gruntRadius();
        u.speed = GameConst::gruntSpeed();
        u.attackRange = GameConst::gruntRange();
        u.attackDamage = GameConst::gruntDamage();
        u.attackCooldown = GameConst::gruntCooldown();
        u.defense = GameConst::gruntDefense();
        u.sightRange = GameConst::gruntSight();
        u.cooldownLeft = 0.0;
        reg.emplace(e, "Unit", u);

        RangeSensor rs = new RangeSensor();
        rs.sensorShapeHandle = sens.handle;
        reg.emplace(e, "RangeSensor", rs);

        reg.emplaceTag(e, "Enemy");
        reg.emplaceTag(e, "Grunt");
        return e;
    }

    // Player Command Center — direct (non-ghost) spawn used by initialMap.
    // Also produced by Spawn::completeConstruction when a CC ghost is built.
    // BaseBuilding tag marks it as a drop-off target for worker resources.
    public static function commandCenter(Registry reg, World world,
                                           float x, float y): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::staticBody());
        bd.setPosition(x, y);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setFilter(Cat::building(), Cat::buildingMask(), 0);
        Shape sh = Shapes::createBox(b, sd, GameConst::commandCenterHalfW(), GameConst::commandCenterHalfH());
        sd.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        Building bldg = new Building();
        bldg.kind = BuildingKind::commandCenter();
        bldg.faction = Faction::player();
        bldg.hp = GameConst::commandCenterHp();
        bldg.maxHp = GameConst::commandCenterHp();
        bldg.defense = GameConst::commandCenterDefense();
        bldg.sightRange = GameConst::commandCenterSight();
        bldg.producing = 0;
        bldg.buildLeft = 0.0;
        bldg.queueLen = 0;
        bldg.rallyX = x + GameConst::commandCenterRallyDx();
        bldg.rallyY = y + GameConst::commandCenterRallyDy();
        reg.emplace(e, "Building", bldg);

        Selectable sel = new Selectable();
        sel.radius = GameConst::commandCenterHalfW() + 0.2;
        reg.emplace(e, "Selectable", sel);

        Pathing::blockArea(x - GameConst::commandCenterHalfW(), y - GameConst::commandCenterHalfH(),
                            x + GameConst::commandCenterHalfW(), y + GameConst::commandCenterHalfH(), true);

        reg.emplaceTag(e, "PlayerControlled");
        reg.emplaceTag(e, "BaseBuilding");
        reg.emplaceTag(e, "CommandCenterTag");
        return e;
    }

    // Mineral pile — static body, box shape, just a place workers walk to.
    public static function resource(Registry reg, World world,
                                     float x, float y, int amount): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::staticBody());
        bd.setPosition(x, y);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setFilter(Cat::resource(), Cat::resourceMask(), 0);
        Shape sh = Shapes::createBox(b, sd, GameConst::resourceHalfW(), GameConst::resourceHalfH());
        sd.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        ResourceNode rn = new ResourceNode();
        rn.amount = amount;
        rn.x = x;
        rn.y = y;
        rn.kind = ResourceKind::minerals();
        reg.emplace(e, "ResourceNode", rn);

        Selectable sel = new Selectable();
        sel.radius = GameConst::resourceHalfW() + 0.2;
        reg.emplace(e, "Selectable", sel);

        Pathing::blockArea(x - GameConst::resourceHalfW(), y - GameConst::resourceHalfH(),
                            x + GameConst::resourceHalfW(), y + GameConst::resourceHalfH(), true);
        return e;
    }

    // Gas geyser — static box, solid, distinct from mineral pile. Workers
    // cannot harvest it directly; a Refinery must be built on top.
    public static function gasGeyser(Registry reg, World world,
                                       float x, float y, int amount): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::staticBody());
        bd.setPosition(x, y);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setFilter(Cat::resource(), Cat::resourceMask(), 0);
        Shape sh = Shapes::createBox(b, sd, GameConst::gasNodeHalfW(), GameConst::gasNodeHalfH());
        sd.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        ResourceNode rn = new ResourceNode();
        rn.amount = amount;
        rn.x = x;
        rn.y = y;
        rn.kind = ResourceKind::gas();
        reg.emplace(e, "ResourceNode", rn);

        Selectable sel = new Selectable();
        sel.radius = GameConst::gasNodeHalfW() + 0.2;
        reg.emplace(e, "Selectable", sel);

        Pathing::blockArea(x - GameConst::gasNodeHalfW(), y - GameConst::gasNodeHalfH(),
                            x + GameConst::gasNodeHalfW(), y + GameConst::gasNodeHalfH(), true);

        reg.emplaceTag(e, "GasGeyser");
        return e;
    }

    // Barracks ghost — sensor body so workers can walk through to build it.
    // Holds Building (with hp=1 so HP bar is full bar at 1/maxHp until
    // completion swaps it) + Construction. completeConstruction promotes it.
    public static function barracksGhost(Registry reg, World world,
                                            float x, float y): int {
        return Spawn::buildingGhost(reg, world, x, y,
                                     BuildingKind::barracks(),
                                     GameConst::barracksHalfW(),
                                     GameConst::barracksHalfH(),
                                     GameConst::barracksHp(),
                                     GameConst::barracksRallyDy(),
                                     GameConst::barracksBuildTime(),
                                     0,
                                     "Barracks");
    }

    public static function refineryGhost(Registry reg, World world,
                                           float x, float y, int geyserEntity): int {
        return Spawn::buildingGhost(reg, world, x, y,
                                     BuildingKind::refinery(),
                                     GameConst::refineryHalfW(),
                                     GameConst::refineryHalfH(),
                                     GameConst::refineryHp(),
                                     0.0,
                                     GameConst::refineryBuildTime(),
                                     geyserEntity,
                                     "RefineryTag");
    }

    public static function commandCenterGhost(Registry reg, World world,
                                                float x, float y): int {
        return Spawn::buildingGhost(reg, world, x, y,
                                     BuildingKind::commandCenter(),
                                     GameConst::commandCenterHalfW(),
                                     GameConst::commandCenterHalfH(),
                                     GameConst::commandCenterHp(),
                                     GameConst::commandCenterRallyDy(),
                                     GameConst::commandCenterBuildTime(),
                                     0,
                                     "CommandCenterTag");
    }

    // Shared ghost builder. `tag` is the per-kind discriminator tag.
    public static function buildingGhost(Registry reg, World world,
                                           float x, float y, int kind,
                                           float halfW, float halfH,
                                           float maxHp, float rallyDy,
                                           float buildTime, int geyserEntity,
                                           string tag): int {
        int e = reg.create();

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::staticBody());
        bd.setPosition(x, y);
        Body b = Bodies::create(world, bd);
        bd.destroy();
        b.setUserDataInt(e);

        ShapeDef sd = new ShapeDef();
        sd.setIsSensor(true);
        sd.setFilter(Cat::sensor(), Cat::unitPlayer(), 0);
        Shape sh = Shapes::createBox(b, sd, halfW, halfH);
        sd.destroy();

        PhysicsBody pb = new PhysicsBody();
        pb.bodyHandle = b.handle;
        reg.emplace(e, "PhysicsBody", pb);

        Building bldg = new Building();
        bldg.kind = kind;
        bldg.faction = Faction::player();
        bldg.hp = 1.0;
        bldg.maxHp = maxHp;
        bldg.defense = 0.0;
        bldg.sightRange = 0.0;
        bldg.producing = 0;
        bldg.buildLeft = 0.0;
        bldg.queueLen = 0;
        bldg.rallyX = x;
        bldg.rallyY = y + rallyDy;
        reg.emplace(e, "Building", bldg);

        Construction c = new Construction();
        c.buildingKind = kind;
        c.progress = 0.0;
        c.buildTime = buildTime;
        c.geyserEntity = geyserEntity;
        reg.emplace(e, "Construction", c);

        Selectable sel = new Selectable();
        sel.radius = halfW + 0.2;
        reg.emplace(e, "Selectable", sel);

        reg.emplaceTag(e, "Ghost");
        reg.emplaceTag(e, "PlayerControlled");
        reg.emplaceTag(e, tag);
        return e;
    }

    // Promote a ghost into a real solid building: destroy its sensor body,
    // create a solid one in the same place, fill HP, drop Construction/Ghost,
    // attach Refinery if applicable, block its footprint for pathing.
    public static function completeConstruction(Registry reg, World world,
                                                  int ghostE): void {
        if (!reg.valid(ghostE)) { return; }
        if (!reg.has(ghostE, "Construction")) { return; }
        if (!reg.has(ghostE, "Building"))     { return; }
        if (!reg.has(ghostE, "PhysicsBody"))  { return; }

        Construction c = (Construction) reg.get(ghostE, "Construction");
        Building bldg = (Building) reg.get(ghostE, "Building");
        PhysicsBody pb = (PhysicsBody) reg.get(ghostE, "PhysicsBody");
        Body oldBody = new Body(pb.bodyHandle);
        float[] p = oldBody.position();
        float px = p[0];
        float py = p[1];
        oldBody.destroy();

        float halfW = GameConst::barracksHalfW();
        float halfH = GameConst::barracksHalfH();
        float hp    = GameConst::barracksHp();
        float def   = GameConst::barracksDefense();
        float sight = GameConst::barracksSight();
        if (c.buildingKind == BuildingKind::refinery()) {
            halfW = GameConst::refineryHalfW();
            halfH = GameConst::refineryHalfH();
            hp    = GameConst::refineryHp();
            def   = GameConst::refineryDefense();
            sight = GameConst::refinerySight();
        } else if (c.buildingKind == BuildingKind::commandCenter()) {
            halfW = GameConst::commandCenterHalfW();
            halfH = GameConst::commandCenterHalfH();
            hp    = GameConst::commandCenterHp();
            def   = GameConst::commandCenterDefense();
            sight = GameConst::commandCenterSight();
        }

        BodyDef bd = new BodyDef();
        bd.setType(BodyType::staticBody());
        bd.setPosition(px, py);
        Body nb = Bodies::create(world, bd);
        bd.destroy();
        nb.setUserDataInt(ghostE);

        ShapeDef sd = new ShapeDef();
        sd.setFilter(Cat::building(), Cat::buildingMask(), 0);
        Shape sh = Shapes::createBox(nb, sd, halfW, halfH);
        sd.destroy();

        pb.bodyHandle = nb.handle;
        reg.emplace(ghostE, "PhysicsBody", pb);

        bldg.hp = hp;
        bldg.maxHp = hp;
        bldg.defense = def;
        bldg.sightRange = sight;
        reg.emplace(ghostE, "Building", bldg);

        Selectable sel = new Selectable();
        sel.radius = halfW + 0.2;
        reg.emplace(ghostE, "Selectable", sel);

        reg.remove(ghostE, "Construction");
        reg.remove(ghostE, "Ghost");

        if (c.buildingKind == BuildingKind::refinery()) {
            Refinery rf = new Refinery();
            rf.geyserEntity = c.geyserEntity;
            reg.emplace(ghostE, "Refinery", rf);
        } else if (c.buildingKind == BuildingKind::commandCenter()) {
            reg.emplaceTag(ghostE, "BaseBuilding");
        }

        Pathing::blockArea(px - halfW, py - halfH, px + halfW, py + halfH, true);
        Audio::playTada();
    }

    // Initial map: 1 base, 4 workers around it, 1 mineral pile, 1 gas
    // Player Command Center at origin, four workers around it, one mineral
    // pile, one gas geyser, two enemy grunts.
    public static function initialMap(Registry reg, World world): void {
        Spawn::commandCenter(reg, world, 0.0, 0.0);

        Spawn::worker(reg, world, -2.5,  2.5);
        Spawn::worker(reg, world,  2.5,  2.5);
        Spawn::worker(reg, world, -2.5, -2.5);
        Spawn::worker(reg, world,  2.5, -2.5);

        Spawn::resource(reg, world, 12.0, 0.0, GameConst::resourceStartAmt());

        Spawn::gasGeyser(reg, world, -12.0, 8.0, GameConst::gasStartAmt());

        Spawn::grunt(reg, world, 24.0,  4.0);
        Spawn::grunt(reg, world, 26.0, -3.0);
    }
}
