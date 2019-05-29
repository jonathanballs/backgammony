module dicewidget;
import std.stdio;
import cairo.Context;

import gl3n.linalg;
import std.format;

struct Point {
    float x, y, z;
}

/*
 * Single die roll. This just handles the animation. Rigid body physics of a
 * spinning cube against a flat surface (the ground). The dice is size 1.0 and
 * will roll in from the right (positive x axis).
 */
class Die {
    vec3 pos;
    vec3 vel;
    float length; // Length of each side
    float mass = 1.0;

    mat3 rot;
    vec3 rotAxis;
    float angVel; // Angular velocity

    this() {
        // Calculate the end position and go back from there.
        pos = vec3(0.0, 0.0, 0.0);
        rot = mat3.identity;

        vel = vec3(-10.0, 0.3, 0.0);
        rotAxis = vec3(0.11, -1.0, 0.0);
        angVel = 22.0;

        // Assume 1 second animation.
        pos -= vel;

        Quaternion!float rotationQuat;
        auto rota = rotationQuat.axis_rotation(angVel, rotAxis).to_matrix!(3, 3);
        rot = rota.inverse() * rot;
    }

    // TODO: Rotation
    vec3[8] calculateVertices() {
        vec3[8] vertices = [
            // Bottom face
            vec3(-0.5, -0.5, -0.5),
            vec3(-0.5,  0.5, -0.5),
            vec3( 0.5,  0.5, -0.5),
            vec3( 0.5, -0.5, -0.5),

            // Top face
            vec3(-0.5, -0.5, 0.5),
            vec3(-0.5,  0.5, 0.5),
            vec3( 0.5,  0.5, 0.5),
            vec3( 0.5, -0.5, 0.5),
        ];

        foreach (ref v; vertices) {
            v = rot * v;
            v += pos;

        }

        return vertices;
    }

    void update(float dt) {
        if (pos.x < 0) return;
        pos += vel * dt;

        if (pos.x < 0) {
            rot = mat3.identity;
            return;
        }
        Quaternion!float rotationQuat;
        auto rota = rotationQuat.axis_rotation(dt * angVel, rotAxis).to_matrix!(3, 3);
        rot = rota * rot;
    }

    // Draw the dice in its current position
    void draw(Context cr) {
        // Ignore z axis, just x and y. Perspective is from above.
        auto vertices = this.calculateVertices();
        int[2][12] edges = [
            [0, 1],
            [1, 2],
            [2, 3],
            [3, 0],

            [4, 5],
            [5, 6],
            [6, 7],
            [7, 4],

            [0, 4],
            [1, 5],
            [2, 6],
            [3, 7],
        ];

        int[4][6] faces = [
            [4, 5, 6, 7], // Top: 1
            [0, 1, 5, 4], // Left: 2
            [2, 3, 7, 6], // Right: 5
            [1, 2, 6, 5], // Front: 3
            [0, 3, 7, 4], // Back: 4
            [0, 1, 2, 3], // Bottom: 6
        ];

        // Cull the edges on the back side of the cube. Find vertex with smallest
        // z value.
        ulong culledVertex;
        foreach (i, v; vertices) {
            if (v.z < vertices[culledVertex].z) culledVertex = i;
        }

        // Paint background
        import std.range : slide;
        cr.setSourceRgb(150/256.0, 40/256.0, 27/256.0);
        cr.moveTo(vertices[0].x, vertices[0].y);
        foreach(face; faces) {
            cr.moveTo(vertices[face[0]].x, vertices[face[0]].y);
            cr.lineTo(vertices[face[1]].x, vertices[face[1]].y);
            cr.lineTo(vertices[face[2]].x, vertices[face[2]].y);
            cr.lineTo(vertices[face[3]].x, vertices[face[3]].y);
            cr.lineTo(vertices[face[0]].x, vertices[face[0]].y);
            cr.fill();
        }

        // Paint lines
        cr.setSourceRgb(170/256.0, 50/256.0, 25/256.0);
        cr.setLineWidth(0.03);
        foreach(edge; edges) {
            if (edge[0] == culledVertex || edge[1] == culledVertex) continue;
            cr.moveTo(vertices[edge[0]].x, vertices[edge[0]].y);
            cr.lineTo(vertices[edge[1]].x, vertices[edge[1]].y);
            cr.stroke();

        }

        // Paint dots
        auto dotPos = vec3(0.0, 0.0, 0.5); // For a 1
        dotPos = rot*dotPos + pos;
        import std.math : PI;
        cr.arc(dotPos.x, dotPos.y, 0.1, 0.0, 2*PI);
        cr.setSourceRgb(1, 1, 1);
        cr.fill();
    }

    override string toString() {
        return format!"Pos: %s, Vel: %s, Rot: %s"(pos, vel, rot);
    }
}
