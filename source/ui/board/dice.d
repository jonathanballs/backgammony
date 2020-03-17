module ui.board.dice;

import std.conv;
import std.datetime;
import std.format;
import std.math : PI, PI_2;
import std.math : atan2;
import std.stdio;
import std.typecons;

import cairo.Context;
import gl3n.linalg;

// Each die face contains the x,y coordinates of the dots and it's matrix
// rotation
private alias DieFace = Tuple!(vec2[], "dots", mat3, "rot");
private DieFace[] dieFaces = [
    // 1
    DieFace([vec2(0.0, 0.0)], mat3.identity),
    // 2
    DieFace([vec2(-0.3, -0.3), vec2(0.3, 0.3)], mat3.identity.rotatex(-PI_2)),
    // 3
    DieFace([vec2(-0.3, -0.3), vec2(0.3, 0.3), vec2(0.0, 0.0)], mat3.identity.rotatey(PI_2)),
    // 4
    DieFace([vec2(-0.3, -0.3), vec2(0.3, 0.3), vec2(-0.3, 0.3), vec2(0.3, -0.3)], mat3.identity.rotatey(-PI_2)),
    // 5
    DieFace([vec2(-0.3, -0.3), vec2(0.3, 0.3), vec2(-0.3, 0.3), vec2(0.3, -0.3), vec2(0.0, 0.0)], mat3.identity.rotatex(PI_2)),
    // 6
    DieFace([vec2(-0.3, -0.3), vec2(0.3, 0.3), vec2(-0.3, 0.3), vec2(0.3, -0.3), vec2(-0.3, 0.0), vec2(0.3, 0.0)], mat3.identity.rotatex(PI))
];

/**
 * Single die roll. This just handles the animation. Rigid body physics of a
 * spinning cube against a flat surface (the ground). The dice is size 1.0 and
 * will roll in from the right (positive x axis).
 */
class AnimatedDie {
    bool finished = false;

    private:

    bool _enableAnimation;

    vec3 pos;
    vec3 vel;
    float length; // Length of each side

    mat3 rot;
    mat3 finalRot;
    vec3 rotAxis;
    float angVel; // Angular velocity

    public SysTime startTime;

    /**
     * Create a new dice widget
     * Params:
     *  diceValue       = The value that the die should display
     *  animationTime   = How long the animation should last
     */
    public this(int diceValue, long animationTime) {
        assert (1 <= diceValue && diceValue <= 6,
            "Can't create dice widget with value " ~ diceValue.to!string);

        // Calculate the end position and go back from there.
        pos.clear(0.0);
        rot = finalRot = dieFaces[diceValue-1].rot.inverse();

        if (!animationTime) {
            finished = true;
            return;
        }

        vel = (1000.0 / animationTime) * vec3(-8.0, 0.6, 0.0);
        rotAxis = vec3(0.11, -1.0, 0.0);
        angVel = (1000.0 / animationTime) * PI * 3;

        // Assume 1 second animation.
        pos -= (animationTime / 1000.0) * vel;

        Quaternion!float rotationQuat;
        auto rota = rotationQuat.axis_rotation((animationTime/1000.0) * angVel, rotAxis).to_matrix!(3, 3);
        rot = rota.inverse() * finalRot;
        startTime = Clock.currTime();
    }

    /**
     * Update the dice roll aniamtion.
     * Params:
     *  dt = Number of seconds that have transpired since the last update
     */
    public void update(float dt) {
        if (finished) return;

        if (pos.x <= 0) {
            rot = finalRot;
            finished = true;
            return;
        }

        pos += vel * dt;

        Quaternion!float rotationQuat;
        auto rota = rotationQuat.axis_rotation(dt * angVel, rotAxis).to_matrix!(3, 3);
        rot = rota * rot;
    }

    // Draw the dice in its current position
    public void draw(Context cr) {
        foreach (face; dieFaces) {
            mat3 faceRot = rot*face.rot;

            // Check whether face is facing up
            if ((faceRot * vec3(0.0, 0.0, 1.0)).z < 0)
                continue;

            auto vertices = [
                vec3(-0.5, -0.5, 0.5),
                vec3(-0.5,  0.5, 0.5),
                vec3( 0.5,  0.5, 0.5),
                vec3( 0.5, -0.5, 0.5)
            ];

            foreach (ref v; vertices) {
                v = faceRot*v + pos;
            }

            // Draw background
            cr.setSourceRgb(150/256.0, 40/256.0, 27/256.0);
            cr.moveTo(vertices[0].x, vertices[0].y);
            cr.lineTo(vertices[1].x, vertices[1].y);
            cr.lineTo(vertices[2].x, vertices[2].y);
            cr.lineTo(vertices[3].x, vertices[3].y);
            cr.lineTo(vertices[0].x, vertices[0].y);
            cr.fillPreserve();

            // Draw Lines
            cr.setSourceRgb(170/256.0, 50/256.0, 25/256.0);
            cr.setLineWidth(0.03);
            cr.stroke();

            // Draw dots
            auto dotHeight = vec2(vertices[0]).distance(vec2(vertices[1]));
            auto dotWidth = vec2(vertices[1]).distance(vec2(vertices[2]));

            if (dotWidth == 0 || dotHeight == 0) continue;

            auto rotVector = vec2(vertices[1]) - vec2(vertices[0]);
            auto dotRotation = atan2(rotVector.y, rotVector.x);

            cr.setSourceRgb(1, 1, 1);
            foreach(dotPosition; face.dots) {
                auto dotPos = rot*face.rot*vec3(dotPosition, 0.5) + pos;
                cr.save();

                cr.translate(dotPos.x, dotPos.y);
                cr.rotate(dotRotation - PI_2);
                cr.scale(dotWidth, dotHeight);
                cr.arc(0.0, 0.0, 0.1, 0.0, 2*PI);
                cr.fill();

                cr.restore();
            }
        }

        if (cr) return;
    }
}
