// Camera state we keep mirrored on the script side because SFML's View
// has no read-back API. Pan via WASD, zoom via wheel. Apply at the end
// of the frame by pushing centerX/centerY/sizeW/sizeH into the View.

import * from "@mtype-sfml/Sfml.mt";
import * from "@mtype-sfml/Graphics.mt";
import * from "../input/Input.mt";

class CameraState {
    public float centerX;
    public float centerY;
    public float sizeW;     // meters of world visible across the window width
    public float sizeH;     // meters of world visible across the window height
    public float baseW;
    public float baseH;
    public float zoom;

    public constructor(float cx, float cy, float w, float h) {
        this.centerX = cx;
        this.centerY = cy;
        this.baseW = w;
        this.baseH = h;
        this.zoom = 1.0;
        this.sizeW = w;
        this.sizeH = h;
    }
}

class CameraCtrl {
    public static int kW = Key::w();
    public static int kA = Key::a();
    public static int kS = Key::s();
    public static int kD = Key::d();

    public static function update(CameraState cam, InputState in, float frameDt): void {
        float pan = 18.0 * frameDt;
        if (Keyboard::isKeyPressed(CameraCtrl::kW)) { cam.centerY = cam.centerY - pan; }
        if (Keyboard::isKeyPressed(CameraCtrl::kS)) { cam.centerY = cam.centerY + pan; }
        if (Keyboard::isKeyPressed(CameraCtrl::kA)) { cam.centerX = cam.centerX - pan; }
        if (Keyboard::isKeyPressed(CameraCtrl::kD)) { cam.centerX = cam.centerX + pan; }

        if (in.wheelDelta != 0.0) {
            float step = 0.1;
            if (in.wheelDelta > 0.0) { cam.zoom = cam.zoom - step; }
            else                       { cam.zoom = cam.zoom + step; }
            if (cam.zoom < 0.4) { cam.zoom = 0.4; }
            if (cam.zoom > 2.5) { cam.zoom = 2.5; }
            cam.sizeW = cam.baseW * cam.zoom;
            cam.sizeH = cam.baseH * cam.zoom;
        }
    }

    public static function apply(View v, CameraState cam): void {
        v.setCenter(cam.centerX, cam.centerY);
        v.setSize(cam.sizeW, cam.sizeH);
    }
}
