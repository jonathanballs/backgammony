module ui.dicewidget;

import std.conv;
import std.stdio;
import std.typecons;
import std.math : atan2;
import cairo.Context;
import std.math : PI, PI_2;

import gl3n.linalg;
import std.format;

/*
 * Single die roll. This just handles the animation. Rigid body physics of a
 * spinning cube against a flat surface (the ground). The dice is size 1.0 and
 * will roll in from the right (positive x axis).
 */

alias DieFace = Tuple!(vec2[], "dots", mat3, "rot");
DieFace[] dieFaces = [
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

class Die {
    vec3 pos;
    vec3 vel;
    float length; // Length of each side

    mat3 rot;
    mat3 finalRot;
    vec3 rotAxis;
    float angVel; // Angular velocity

    bool finished = false;

    this(int diceValue) {
        assert (1 <= diceValue && diceValue <= 6,
            "Can't create dice widget with value " ~ diceValue.to!string);
        // Calculate the end position and go back from there.
        pos = vec3(0.0, 0.0, 0.0);
        finalRot = rot = dieFaces[diceValue-1].rot.inverse();

        vel = vec3(-4.0, 0.3, 0.0);
        rotAxis = vec3(0.11, -1.0, 0.0);
        angVel = PI * 3;

        // Assume 1 second animation.
        pos -= 2 * vel;

        Quaternion!float rotationQuat;
        auto rota = rotationQuat.axis_rotation(2 * angVel, rotAxis).to_matrix!(3, 3);
        rot = rota.inverse() * rot;
    }

    void update(float dt) {
        if (pos.x < 0) {
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
    void draw(Context cr) {
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

    override string toString() {
        return format!"Pos: %s, Vel: %s, Rot: %s"(pos, vel, rot);
    }
}

