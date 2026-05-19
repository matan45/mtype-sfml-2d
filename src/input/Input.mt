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

class CommandMode {
    public static function normal():     int { return 0; }
    public static function attackMove(): int { return 1; }
}

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
    public bool  attackMovePressed;
    public bool  stopPressed;
    public int   commandMode;
    // True if any ImGui window was hovered at the end of the *previous*
    // frame. Used to gate mouse-down edges so HUD clicks don't fall
    // through to the world. ImGui::isWindowHovered() at pump time is
    // unreliable (no window context is active yet), hence this mirror.
    public bool  imguiHovered;

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
        this.attackMovePressed = false;
        this.stopPressed = false;
        this.commandMode = CommandMode::normal();
        this.imguiHovered = false;
    }

    public function clearEdges(): void {
        this.leftDownEdge = false;
        this.leftUpEdge = false;
        this.rightClickEdge = false;
        this.wheelDelta = 0.0;
        this.attackMovePressed = false;
        this.stopPressed = false;
    }
}

class Input {
    // Lazily-cached event-id and key constants. Resolved on first pump()
    // call rather than at class-load time — the SFML plugin natives that
    // back closedEventId() / keyPressedEventId() / etc. aren't present
    // until main.mt has called __plugin_load.
    public static int idClosed     = 0;
    public static int idKeyPressed = 0;
    public static int idMouseDown  = 0;
    public static int idMouseUp    = 0;
    public static int idMouseMoved = 0;
    public static int idMouseWheel = 0;

    public static int kEsc = 0;
    public static int kF1  = 0;
    public static int kQ   = 0;
    public static int kE   = 0;

    public static int mLeft  = 0;
    public static int mRight = 0;

    public static int ready = 0;

    public static function ensureReady(): void {
        if (Input::ready == 1) { return; }
        Input::idClosed     = Sfml::closedEventId();
        Input::idKeyPressed = Sfml::keyPressedEventId();
        Input::idMouseDown  = Sfml::mouseButtonPressedEventId();
        Input::idMouseUp    = Sfml::mouseButtonReleasedEventId();
        Input::idMouseMoved = Sfml::mouseMovedEventId();
        Input::idMouseWheel = Sfml::mouseWheelScrolledEventId();
        Input::kEsc   = Key::escape();
        Input::kF1    = Key::f1();
        Input::kQ     = Key::q();
        Input::kE     = Key::e();
        Input::mLeft  = MouseButton::left();
        Input::mRight = MouseButton::right();
        Input::ready = 1;
    }

    public static function pump(RenderWindow win, InputState s): void {
        Input::ensureReady();
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
                    if (s.commandMode != CommandMode::normal()) {
                        s.commandMode = CommandMode::normal();
                    } else {
                        s.quitRequested = true;
                    }
                } else if (k == Input::kF1) {
                    s.debugDraw = !s.debugDraw;
                } else if (k == Input::kQ) {
                    s.attackMovePressed = true;
                    s.commandMode = CommandMode::attackMove();
                } else if (k == Input::kE) {
                    s.stopPressed = true;
                    s.commandMode = CommandMode::normal();
                }
            } else if (ev == Input::idMouseDown) {
                int b = Event::mouseButton();
                s.mouseX = Event::mouseX();
                s.mouseY = Event::mouseY();
                if (b == Input::mLeft) {
                    if (!s.imguiHovered) {
                        s.leftDownEdge = true;
                        s.leftHeld = true;
                    }
                } else if (b == Input::mRight) {
                    if (!s.imguiHovered) {
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
