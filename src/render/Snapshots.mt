// Plain-old-data snapshots populated each frame from the registry. The
// renderer consumes these so it doesn't have to import the EnTT bindings
// (which would collide with Graphics.mt's `View` class).

class WorldSnapshot {
    // Units
    public int     unitCount;
    public float[] unitX;
    public float[] unitY;
    public float[] unitRadius;
    public int[]   unitFaction;
    public float[] unitHp;
    public float[] unitMaxHp;
    public float[] unitAttack;
    public float[] unitDefense;

    // Buildings
    public int     buildingCount;
    public float[] buildingX;
    public float[] buildingY;
    public float[] buildingHw;
    public float[] buildingHh;
    public int[]   buildingFaction;
    public int[]   buildingKind;
    public float[] buildingHp;
    public float[] buildingMaxHp;
    public float[] buildingDefense;
    public int[]   buildingIsGhost;
    public float[] buildingProgress;

    // Resources
    public int     resourceCount;
    public float[] resourceX;
    public float[] resourceY;
    public float[] resourceHw;
    public float[] resourceHh;
    public int[]   resourceKind;

    // Selected (any entity that has the Selected tag and a position)
    public int     selectedCount;
    public float[] selectedX;
    public float[] selectedY;
    public float[] selectedRadius;

    // Fog of war: gs*gs ints, mirrored from Fog::state. 0=unexplored,
    // 1=explored, 2=visible. gs is the world grid size from GameConst.
    public int[]   fogState;
    // Same data as float[] for direct upload as a shader uniform array.
    public float[] fogStateF;

    public constructor() {
        int cap = 256;
        this.unitCount = 0;
        this.unitX        = new float[cap];
        this.unitY        = new float[cap];
        this.unitRadius   = new float[cap];
        this.unitFaction  = new int[cap];
        this.unitHp       = new float[cap];
        this.unitMaxHp    = new float[cap];
        this.unitAttack   = new float[cap];
        this.unitDefense  = new float[cap];

        this.buildingCount     = 0;
        int bcap = 64;
        this.buildingX         = new float[bcap];
        this.buildingY         = new float[bcap];
        this.buildingHw        = new float[bcap];
        this.buildingHh        = new float[bcap];
        this.buildingFaction   = new int[bcap];
        this.buildingKind      = new int[bcap];
        this.buildingHp        = new float[bcap];
        this.buildingMaxHp     = new float[bcap];
        this.buildingDefense   = new float[bcap];
        this.buildingIsGhost   = new int[bcap];
        this.buildingProgress  = new float[bcap];

        this.resourceCount = 0;
        int rcap = 64;
        this.resourceX     = new float[rcap];
        this.resourceY     = new float[rcap];
        this.resourceHw    = new float[rcap];
        this.resourceHh    = new float[rcap];
        this.resourceKind  = new int[rcap];

        this.selectedCount  = 0;
        this.selectedX      = new float[cap];
        this.selectedY      = new float[cap];
        this.selectedRadius = new float[cap];

        this.fogState  = new int[4096];
        this.fogStateF = new float[4096];
    }
}
