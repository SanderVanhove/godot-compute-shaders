#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 2, local_size_y = 2, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer MyDataBuffer {
    float data[];
}
my_data_buffer;

layout(set = 0, binding = 1, std430) restrict buffer MyParams{
    float data[];
}
params;

uint get_coord(uint x, uint y) {
    return x + y * int(params.data[0]);
}

// The code we want to execute in each invocation
void main() {
    uint x = gl_GlobalInvocationID.x;
    uint y = gl_GlobalInvocationID.y;
    int neighbors = 0;

    neighbors += int(floor(my_data_buffer.data[get_coord(x - int(params.data[8]), y - int(params.data[8]))]));
    neighbors += int(floor(my_data_buffer.data[get_coord(x, y - int(params.data[8]))]));
    neighbors += int(floor(my_data_buffer.data[get_coord(x + int(params.data[8]), y - int(params.data[8]))]));

    neighbors += int(floor(my_data_buffer.data[get_coord(x + int(params.data[8]), y)]));
    neighbors += int(floor(my_data_buffer.data[get_coord(x - int(params.data[8]), y)]));

    neighbors += int(floor(my_data_buffer.data[get_coord(x - int(params.data[8]), y + int(params.data[8]))]));
    neighbors += int(floor(my_data_buffer.data[get_coord(x, y + int(params.data[8]))]));
    neighbors += int(floor(my_data_buffer.data[get_coord(x + int(params.data[8]), y + int(params.data[8]))]));

    float value = my_data_buffer.data[get_coord(x, y)];

    if (length(vec2(params.data[5], params.data[6]) - vec2(x, y)) < params.data[7])
        value = 0.0;
    else if (value == 1.0) {
        if (neighbors < params.data[2] || neighbors > params.data[1])
            value = 0.9;
    } else if (neighbors == params.data[3])
        value = 1.0;
    else if (value > 0.0 && value < 1.0)
        value -= params.data[4];
    
    my_data_buffer.data[get_coord(x, y)] = clamp(value, 0.0, 1.0);
}
