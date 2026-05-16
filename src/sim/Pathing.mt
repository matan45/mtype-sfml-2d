// 64x64 grid pathfinding with A* and line-of-sight waypoint smoothing.
//
// Cells are 1m × 1m. World x/y in [-32, 32) map to cell index (cx, cy)
// where cx = floor(x + 32), cy = floor(y + 32). blocked[cy*64+cx] = 1
// marks an obstacle. Only static obstacles (buildings, resource nodes)
// are marked — units don't write the grid; Box2D handles unit-unit.
//
// Path data lives in a global ArrayList<PathEntry> side-map keyed by
// entity id. < 200 simultaneous paths is the design budget; linear
// lookup is fine at that scale.

import * from "@mtype-entt/Entt.mt";
import * from "@mtype-box2d/Body.mt";

import * from "../game/Constants.mt";

class PathEntry {
    public int     entity;
    public float[] xs;
    public float[] ys;
    public int     count;

    public constructor(int e, float[] x, float[] y, int n) {
        this.entity = e;
        this.xs = x;
        this.ys = y;
        this.count = n;
    }
}

class Pathing {
    // 64*64 = 4096 cells.
    public static int[] blocked = new int[4096];
    public static int   inited  = 0;

    // Fixed-cap path side-map. Linear scan; > 128 simultaneous paths
    // overflows silently — fine for an MVP with ~30 active units.
    public static int            pathCap  = 128;
    public static PathEntry[]    pathArr  = new PathEntry[128];
    public static int            pathLen  = 0;

    public static function ensureInit(): void {
        if (Pathing::inited == 1) { return; }
        int n = 4096;
        int i = 0;
        while (i < n) { Pathing::blocked[i] = 0; i = i + 1; }
        Pathing::inited = 1;
    }

    public static function inBounds(int cx, int cy): bool {
        if (cx < 0) { return false; }
        if (cy < 0) { return false; }
        if (cx >= GameConst::gridSize()) { return false; }
        if (cy >= GameConst::gridSize()) { return false; }
        return true;
    }

    public static function toCellX(float x): int {
        return (int)(x + GameConst::worldHalf());
    }
    public static function toCellY(float y): int {
        return (int)(y + GameConst::worldHalf());
    }
    public static function fromCellX(int cx): float {
        return (float)cx - GameConst::worldHalf() + 0.5;
    }
    public static function fromCellY(int cy): float {
        return (float)cy - GameConst::worldHalf() + 0.5;
    }

    public static function isBlocked(int cx, int cy): bool {
        if (!Pathing::inBounds(cx, cy)) { return true; }
        return Pathing::blocked[cy * GameConst::gridSize() + cx] == 1;
    }

    // Mark or clear an axis-aligned rect of cells [minX, maxX) x [minY, maxY)
    // in WORLD coords. Used by Spawn for buildings and resource nodes.
    public static function blockArea(float minX, float minY,
                                       float maxX, float maxY, bool block): void {
        Pathing::ensureInit();
        int cx0 = Pathing::toCellX(minX);
        int cy0 = Pathing::toCellY(minY);
        int cx1 = Pathing::toCellX(maxX);
        int cy1 = Pathing::toCellY(maxY);
        int v = 0;
        if (block) { v = 1; }
        int y = cy0;
        while (y <= cy1) {
            int x = cx0;
            while (x <= cx1) {
                if (Pathing::inBounds(x, y)) {
                    Pathing::blocked[y * GameConst::gridSize() + x] = v;
                }
                x = x + 1;
            }
            y = y + 1;
        }
    }

    // ---- path side-map ----
    public static function findPath(int e): PathEntry {
        int n = Pathing::pathLen;
        int i = 0;
        while (i < n) {
            PathEntry p = Pathing::pathArr[i];
            if (p.entity == e) { return p; }
            i = i + 1;
        }
        return null;
    }
    public static function clearPath(int e): void {
        int n = Pathing::pathLen;
        int i = 0;
        while (i < n) {
            PathEntry p = Pathing::pathArr[i];
            if (p.entity == e) {
                Pathing::pathArr[i] = Pathing::pathArr[n - 1];
                Pathing::pathArr[n - 1] = null;
                Pathing::pathLen = n - 1;
                return;
            }
            i = i + 1;
        }
    }
    public static function setPath(int e, float[] xs, float[] ys, int count): void {
        Pathing::clearPath(e);
        if (Pathing::pathLen >= Pathing::pathCap) { return; }
        Pathing::pathArr[Pathing::pathLen] = new PathEntry(e, xs, ys, count);
        Pathing::pathLen = Pathing::pathLen + 1;
    }

    // Bresenham line walk over cells. Returns true if no blocked cell on
    // the open segment between (x0, y0) and (x1, y1).
    public static function hasLineOfSight(float x0, float y0,
                                            float x1, float y1): bool {
        int cx0 = Pathing::toCellX(x0);
        int cy0 = Pathing::toCellY(y0);
        int cx1 = Pathing::toCellX(x1);
        int cy1 = Pathing::toCellY(y1);

        int dx = cx1 - cx0;
        if (dx < 0) { dx = -dx; }
        int dy = cy1 - cy0;
        if (dy < 0) { dy = -dy; }

        int sx = -1;
        if (cx0 < cx1) { sx = 1; }
        int sy = -1;
        if (cy0 < cy1) { sy = 1; }

        int err = dx - dy;
        int x = cx0;
        int y = cy0;
        while (true) {
            if (Pathing::isBlocked(x, y)) { return false; }
            if (x == cx1 && y == cy1) { return true; }
            int e2 = 2 * err;
            if (e2 > -dy) { err = err - dy; x = x + sx; }
            if (e2 <  dx) { err = err + dx; y = y + sy; }
        }
        return true;
    }

    // A* on the static grid. Returns flat [x0, y0, x1, y1, ...] world
    // waypoints (length 2*N). Empty when start == goal or unreachable.
    public static function astar(float sx, float sy,
                                   float gx, float gy): float[] {
        Pathing::ensureInit();
        int N = GameConst::gridSize();
        int total = N * N;

        int sCx = Pathing::toCellX(sx);
        int sCy = Pathing::toCellY(sy);
        int gCx = Pathing::toCellX(gx);
        int gCy = Pathing::toCellY(gy);

        if (!Pathing::inBounds(sCx, sCy)) { float[] empty = new float[0]; return empty; }
        if (!Pathing::inBounds(gCx, gCy)) { float[] empty = new float[0]; return empty; }

        // If the goal cell itself is blocked, walk outward up to 2 cells
        // to find a passable substitute — common when right-clicking onto
        // a mineral pile.
        if (Pathing::isBlocked(gCx, gCy)) {
            int found = 0;
            int r = 1;
            while (r <= 3 && found == 0) {
                int dy = -r;
                while (dy <= r && found == 0) {
                    int dx = -r;
                    while (dx <= r && found == 0) {
                        int nx = gCx + dx;
                        int ny = gCy + dy;
                        if (Pathing::inBounds(nx, ny) && !Pathing::isBlocked(nx, ny)) {
                            gCx = nx;
                            gCy = ny;
                            found = 1;
                        }
                        dx = dx + 1;
                    }
                    dy = dy + 1;
                }
                r = r + 1;
            }
            if (found == 0) { float[] empty = new float[0]; return empty; }
        }

        if (sCx == gCx && sCy == gCy) { float[] empty = new float[0]; return empty; }

        int[]   cameFrom = new int[total];
        int[]   gScore   = new int[total];
        int[]   fScore   = new int[total];
        int[]   inOpen   = new int[total];
        int[]   closed   = new int[total];
        int     INF      = 1000000000;
        int i = 0;
        while (i < total) {
            cameFrom[i] = -1;
            gScore[i]   = INF;
            fScore[i]   = INF;
            inOpen[i]   = 0;
            closed[i]   = 0;
            i = i + 1;
        }

        int startIdx = sCy * N + sCx;
        int goalIdx  = gCy * N + gCx;
        gScore[startIdx] = 0;
        int h0 = Pathing::manhattan(sCx, sCy, gCx, gCy);
        fScore[startIdx] = h0;
        inOpen[startIdx] = 1;

        int openCount = 1;
        int dxArr0 =  1; int dyArr0 =  0;
        int dxArr1 = -1; int dyArr1 =  0;
        int dxArr2 =  0; int dyArr2 =  1;
        int dxArr3 =  0; int dyArr3 = -1;

        while (openCount > 0) {
            // Pick min-fScore from open set (linear scan — fine for 4096).
            int cur = -1;
            int bestF = INF + 1;
            int k = 0;
            while (k < total) {
                if (inOpen[k] == 1 && fScore[k] < bestF) {
                    bestF = fScore[k];
                    cur = k;
                }
                k = k + 1;
            }
            if (cur < 0) { break; }
            if (cur == goalIdx) {
                return Pathing::reconstruct(cameFrom, cur, sCx, sCy, gCx, gCy);
            }
            inOpen[cur] = 0;
            closed[cur] = 1;
            openCount = openCount - 1;

            int cx = cur % N;
            int cy = cur / N;

            int ni = 0;
            while (ni < 4) {
                int ndx = dxArr0; int ndy = dyArr0;
                if (ni == 1) { ndx = dxArr1; ndy = dyArr1; }
                if (ni == 2) { ndx = dxArr2; ndy = dyArr2; }
                if (ni == 3) { ndx = dxArr3; ndy = dyArr3; }
                int nx = cx + ndx;
                int ny = cy + ndy;
                if (Pathing::inBounds(nx, ny) && !Pathing::isBlocked(nx, ny)) {
                    int nIdx = ny * N + nx;
                    if (closed[nIdx] == 0) {
                        int tentative = gScore[cur] + 1;
                        if (tentative < gScore[nIdx]) {
                            cameFrom[nIdx] = cur;
                            gScore[nIdx] = tentative;
                            int hN = Pathing::manhattan(nx, ny, gCx, gCy);
                            fScore[nIdx] = tentative + hN;
                            if (inOpen[nIdx] == 0) {
                                inOpen[nIdx] = 1;
                                openCount = openCount + 1;
                            }
                        }
                    }
                }
                ni = ni + 1;
            }
        }
        float[] empty = new float[0];
        return empty;
    }

    public static function manhattan(int x0, int y0, int x1, int y1): int {
        int dx = x1 - x0;
        if (dx < 0) { dx = -dx; }
        int dy = y1 - y0;
        if (dy < 0) { dy = -dy; }
        return dx + dy;
    }

    // Walk cameFrom from goal to start, then reverse + smooth with LoS.
    public static function reconstruct(int[] cameFrom, int goal,
                                         int sCx, int sCy, int gCx, int gCy): float[] {
        int N = GameConst::gridSize();
        // Worst case 4096 entries; we'll trim.
        int[] rawX = new int[4096];
        int[] rawY = new int[4096];
        int len = 0;
        int cur = goal;
        while (cur >= 0) {
            rawX[len] = cur % N;
            rawY[len] = cur / N;
            len = len + 1;
            cur = cameFrom[cur];
        }
        // Reverse into world coords.
        float[] preX = new float[len];
        float[] preY = new float[len];
        int i = 0;
        while (i < len) {
            int rx = rawX[len - 1 - i];
            int ry = rawY[len - 1 - i];
            preX[i] = Pathing::fromCellX(rx);
            preY[i] = Pathing::fromCellY(ry);
            i = i + 1;
        }
        // LoS smoothing: keep [0], then jump as far as possible from there.
        float[] outX = new float[len];
        float[] outY = new float[len];
        int outN = 0;
        outX[outN] = preX[0];
        outY[outN] = preY[0];
        outN = outN + 1;
        int anchor = 0;
        while (anchor < len - 1) {
            int probe = len - 1;
            while (probe > anchor + 1) {
                if (Pathing::hasLineOfSight(preX[anchor], preY[anchor],
                                              preX[probe], preY[probe])) {
                    break;
                }
                probe = probe - 1;
            }
            outX[outN] = preX[probe];
            outY[outN] = preY[probe];
            outN = outN + 1;
            anchor = probe;
        }
        // Flat [x0, y0, x1, y1, ...] — drop the start node, callers steer
        // from current body position, not the cell center.
        int startSkip = 1;
        if (outN <= startSkip) { float[] empty = new float[0]; return empty; }
        float[] flat = new float[(outN - startSkip) * 2];
        int j = startSkip;
        int o = 0;
        while (j < outN) {
            flat[o]     = outX[j];
            flat[o + 1] = outY[j];
            o = o + 2;
            j = j + 1;
        }
        return flat;
    }

    // Compute a path for entity e from its current world pos to (gx, gy).
    // Stores the result in the path side-map and returns the number of
    // waypoints (0 if unreachable or already there).
    public static function plan(int e, World world, int bodyHandle,
                                  float gx, float gy): int {
        Body b = new Body(bodyHandle);
        float[] p = b.position();
        float[] flat = Pathing::astar(p[0], p[1], gx, gy);
        int n = flat.length / 2;
        if (n == 0) {
            Pathing::clearPath(e);
            return 0;
        }
        float[] xs = new float[n];
        float[] ys = new float[n];
        int i = 0;
        while (i < n) {
            xs[i] = flat[i * 2];
            ys[i] = flat[i * 2 + 1];
            i = i + 1;
        }
        Pathing::setPath(e, xs, ys, n);
        return n;
    }
}
