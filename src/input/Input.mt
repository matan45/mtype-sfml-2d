// Per-frame input snapshot built by Input::pump. Drains the SFML event
// queue, forwards every event to ImGui, and accumulates a tiny set of
// edge events the rest of the game cares about (left click down/up,
// right click, scroll, F1, Esc).
//
// Realtime polling (WASD pan, modifier keys) is read directly from
// Keyboard::isKeyPressed in the systems that need it — no need to mirror.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/Graphics.mt";
import * from "@mtype-sfml/ImGui.mt";

class InputState {
    public int   mouseX;
    public int   mouseY;
    public bool  leftDownEdge;
    public bool  leftUpEdge;
    public bool  rightClickEdge;
    public bool  leftHeld;
    public float wheelDelta;
    public bool  debugDraw;
    public bool  quitRequested;

    public constructor() {
        this.mouseX = 0;
        this.mouseY = 0;
        this.leftDownEdge = false;
        this.leftUpEdge = false;
        this.rightClickEdge = false;
        this.leftHeld = false;
        this.wheelDelta = 0.0;
        this.debugDraw = false;
        this.quitRequested = false;
    }

    public function clearEdges(): void {
        this.leftDownEdge = false;
        this.leftUpEdge = false;
        this.rightClickEdge = false;
        this.wheelDelta = 0.0;
    }
}

class Input {
    // Cached event-id constants so we don't re-resolve them per event.
    public static int idClosed       = Sfml::closedEventId();
    public static int idKeyPressed   = Sfml::keyPressedEventId();
    public static int idMouseDown    = Sfml::mouseButtonPressedEventId();
    public static int idMouseUp      = Sfml::mouseButtonReleasedEventId();
    public static int idMouseMoved   = Sfml::mouseMovedEventId();
    public static int idMouseWheel   = Sfml::mouseWheelScrolledEventId();

    public static int kEsc = Key::escape();
    public static int kF1  = Key::f1();

    public static int mLeft  = MouseButton::left();
    public static int mRight = MouseButton::right();

    public static function pump(RenderWindow win, InputState s): void {
        s.clearEdges();
        // Refresh current cursor position from window every frame so the
        // selection box can use it even when the mouse hasn't moved.
        int[] mp = win.mousePosition();
        s.mouseX = mp[0];
        s.mouseY = mp[1];

        int ev = win.pollEvent();
        while (ev != 0) {
            ImGui::processSfmlEvent(win);

            if (ev == Input::idClosed) {
                s.quitRequested = true;
            } else if (ev == Input::idKeyPressed) {
                int k = Event::key();
                if (k == Input::kEsc) {
                    s.quitRequested = true;
                } else if (k == Input::kF1) {
                    s.debugDraw = !s.debugDraw;
                }
            } else if (ev == Input::idMouseDown) {
                int b = Event::mouseButton();
                s.mouseX = Event::mouseX();
                s.mouseY = Event::mouseY();
                if (b == Input::mLeft) {
                    if (!ImGui::isWindowHovered()) {
                        s.leftDownEdge = true;
                        s.leftHeld = true;
                    }
                } else if (b == Input::mRight) {
                    if (!ImGui::isWindowHovered()) {
                        s.rightClickEdge = true;
                    }
                }
            } else if (ev == Input::idMouseUp) {
                int b = Event::mouseButton();
                s.mouseX = Event::mouseX();
                s.mouseY = Event::mouseY();
                if (b == Input::mLeft) {
                    if (s.leftHeld) { s.leftUpEdge = true; }
                    s.leftHeld = false;
                }
            } else if (ev == Input::idMouseMoved) {
                s.mouseX = Event::mouseX();
                s.mouseY = Event::mouseY();
            } else if (ev == Input::idMouseWheel) {
                s.wheelDelta = s.wheelDelta + Event::wheelDelta();
            }

            ev = win.pollEvent();
        }
    }
}

// Screen pixel <-> world meter conversion. View center/size are tracked
// outside the SFML View (which has no read-back API) — see CameraState.
class ScreenWorld {
    // px,py = window-local pixel; (cx,cy) = view center; (vw,vh) = view
    // size in meters; (ww,wh) = window pixel size. Returns [wx, wy].
    public static function toWorld(int px, int py,
                                    float cx, float cy,
                                    float vw, float vh,
                                    int ww, int wh): float[] {
        float fx = (float)px - ((float)ww) * 0.5;
        float fy = (float)py - ((float)wh) * 0.5;
        float wx = cx + fx * (vw / ((float)ww));
        float wy = cy + fy * (vh / ((float)wh));
        float[] r = new float[2];
        r[0] = wx;
        r[1] = wy;
        return r;
    }
}
