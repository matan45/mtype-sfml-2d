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

    // Buildings
    public int     buildingCount;
    public float[] buildingX;
    public float[] buildingY;
    public float[] buildingHw;
    public float[] buildingHh;
    public int[]   buildingFaction;

    // Resources
    public int     resourceCount;
    public float[] resourceX;
    public float[] resourceY;
    public float[] resourceHw;
    public float[] resourceHh;

    // Selected (any entity that has the Selected tag and a position)
    public int     selectedCount;
    public float[] selectedX;
    public float[] selectedY;
    public float[] selectedRadius;

    public constructor() {
        int cap = 256;
        this.unitCount = 0;
        this.unitX        = new float[cap];
        this.unitY        = new float[cap];
        this.unitRadius   = new float[cap];
        this.unitFaction  = new int[cap];
        this.unitHp       = new float[cap];
        this.unitMaxHp    = new float[cap];

        this.buildingCount    = 0;
        int bcap = 64;
        this.buildingX        = new float[bcap];
        this.buildingY        = new float[bcap];
        this.buildingHw       = new float[bcap];
        this.buildingHh       = new float[bcap];
        this.buildingFaction  = new int[bcap];

        this.resourceCount = 0;
        int rcap = 64;
        this.resourceX     = new float[rcap];
        this.resourceY     = new float[rcap];
        this.resourceHw    = new float[rcap];
        this.resourceHh    = new float[rcap];

        this.selectedCount  = 0;
        this.selectedX      = new float[cap];
        this.selectedY      = new float[cap];
        this.selectedRadius = new float[cap];
    }
}
