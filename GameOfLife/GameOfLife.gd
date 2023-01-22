extends Node2D

var shader
var rd: RenderingDevice
var frame: Array = []
var inputs: Array = []

@onready var sprite: Sprite2D = $Sprite

@export_range(32, 258, 1) var size: int = 64
@export_range(0, 10) var max_n: int = 3
@export_range(0, 10) var min_n: int = 2
@export_range(0, 10) var life_n: int = 3
@export_range(0, 1, .01) var decay: float = 3
@export_range(0, 100) var kill_dist: int = 10
@export_range(1, 10) var n_dist: int = 2
@export var gradient: Gradient


func _ready():
	# Create a local rendering device.
	rd = RenderingServer.create_local_rendering_device()
	var shader_file := load("res://GameOfLife/game_of_life.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	
	for i in size * size:
		frame.append(roundi(randf()))
		
	var image: Image = Image.create(size, size, true, Image.FORMAT_RGBA8)
	
	while true:
		for i in frame.size():
			image.set_pixel(int(i) % size, floor(i / size), gradient.sample(frame[i]) * randf_range(.8, 1.1))
		sprite.texture = ImageTexture.create_from_image(image)
		
		await get_tree().create_timer(.05).timeout
		frame = compute_step(frame)


func compute_step(frame: Array):
	# Prepare our data. We use floats in the shader, so we need 32 bit.
	var input: PackedFloat32Array = PackedFloat32Array(frame)
	var input_bytes: PackedByteArray = input.to_byte_array()

	var buffer: RID = rd.storage_buffer_create(input_bytes.size(), input_bytes)
	# Create a uniform to assign the buffer to the rendering device
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	# this needs to match the "binding" in our shader file
	uniform.binding = 0
	uniform.add_id(buffer)
	
	var size_buff := PackedFloat32Array([
		size,
		max_n,
		min_n,
		life_n,
		decay,
		sprite.get_local_mouse_position().x + size / 2,
		sprite.get_local_mouse_position().y + size / 2,
		kill_dist,
		n_dist
	])
	var buffer2 := rd.storage_buffer_create(size_buff.to_byte_array().size(), size_buff.to_byte_array())
	var uniform2 := RDUniform.new()
	uniform2.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform2.binding = 1
	uniform2.add_id(buffer2)
	
	# the last parameter (the 0) needs to match the "set" in our shader file
	var uniform_set := rd.uniform_set_create([uniform, uniform2], shader, 0)
	
	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, size / 2, size / 2, 1)
	rd.compute_list_end()
	
	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()
	
	# Read back the data from the buffer
	var output_bytes := rd.buffer_get_data(buffer)
	var output := output_bytes.to_float32_array()
	
	return output
