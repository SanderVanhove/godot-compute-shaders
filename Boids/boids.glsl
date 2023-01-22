#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer MyDataBuffer {
    float data[];
}
data;

layout(set = 0, binding = 1, std430) restrict buffer MyParams{
    float data[];
}
params;

uint get_coord(uint x, uint y) {
    return x + y * int(params.data[0]);
}

vec2 get_position(uint agent_id, uint num_agents) {
    return vec2(data.data[agent_id], data.data[agent_id + num_agents]);
}

vec2 get_velocity(uint agent_id, uint num_agents) {
    return vec2(data.data[agent_id + num_agents * 2], data.data[agent_id + num_agents * 3]);
}

// The code we want to execute in each invocation
void main() {
    uint agent_id = gl_GlobalInvocationID.x;
    float size = params.data[0];
    uint num_agents= uint(params.data[1]);

    float coherence = params.data[2];
    float separation = params.data[3];
    float alignment = params.data[4];
    float visual_range = params.data[5];
    float wall_fear = params.data[7];
    float wall_dist = params.data[15];
    float slow_down = params.data[8];

    float max_speed = params.data[6];

    vec2 mouse_pos = vec2(params.data[10], params.data[11]);
    float mouse_attraction = params.data[13] * params.data[12];
    float mouse_view_dist = params.data[14];

    vec2 pos = get_position(agent_id, num_agents);
    vec2 vel = get_velocity(agent_id, num_agents);

    vec2 cum_center = vec2(0.0);
    vec2 cum_move = vec2(0.0);
    vec2 cum_vel = vec2(0.0);

    uint seen_neighbours = 0;

    for (uint i = 0; i < num_agents; i++) {
        if (i == agent_id)
            continue;
        
        vec2 other_pos = get_position(i, num_agents);
        float dist = length(pos - other_pos) / visual_range;
        if (dist > 1.0)
            continue;
        
        cum_center += other_pos;
        cum_move += (pos - other_pos);
        cum_vel += get_velocity(i, num_agents);

        seen_neighbours++;
    }

    vel *= slow_down;
    if (seen_neighbours > 0.0) {
        vec2 center = cum_center / seen_neighbours;
        vec2 coherence_force = (center - pos) * coherence;

        vec2 separation_force = cum_move * separation;

        vec2 average_velocity = cum_vel / seen_neighbours;
        vec2 alignment_force = (average_velocity - vel) * alignment;

        vec2 boid_force = coherence_force + separation_force + alignment_force;
        vel += boid_force;
    }

    if (pos.x <= wall_dist)
        vel.x += (wall_dist - abs(pos.x)) / wall_dist;
    else if (pos.x >= (size - wall_dist))
        vel.x += (pos.x - size) / wall_dist;

    if (pos.y <= wall_dist)
        vel.y += (wall_dist - pos.y) / wall_dist;
    else if (pos.y >= (size - wall_dist))
        vel.y += (pos.y - size) / wall_dist;

    /*
    if (pos.y <= wall_dist)
        vel.y += (wall_dist - pos.y) / wall_dist;
    else if (pos.x >= (size - wall_dist))
        vel.y += (pos.y - size) * wall_fear;
    */

    if (length(mouse_pos - pos) < mouse_view_dist)
        vel += normalize(mouse_pos - pos) * mouse_attraction;

    if (length(vel) > max_speed)
        vel = normalize(vel) * max_speed;

    pos += vel;

    if (pos.x < 0.0)
        pos.x = 0.0;
    else if (pos.x >= size)
        pos.x = size - 1.0;

    if (pos.y < 0.0)
        pos.y = 0.0;
    else if (pos.y >= size)
        pos.y = size - 1.0;

    data.data[agent_id] = pos.x;
    data.data[agent_id + num_agents] = pos.y;
    data.data[agent_id + num_agents * 2] = vel.x;
    data.data[agent_id + num_agents * 3] = vel.y;
}
