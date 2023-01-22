extends Node2D

var shader
var rd: RenderingDevice
var frame: Array = []
var inputs: Array = []

@onready var sprite: Sprite2D = $Sprite

@export_range(32, 516, 1) var size: int = 64
@export_range(0, 1000000) var num_agents: int = 100

@export_range(0, 2, .001) var coherence: float = .5
@export_range(0.0, .1, .0001) var separation: float = .5
@export_range(0, 2, .001) var alignment: float = .5
@export_range(0, 1, .01) var wall_fear: float = .5
@export_range(0, 100, .01) var wall_dist: float = 10
@export_range(0, 1, .001) var slowdown: float = .1
@export_range(0, 100, .01) var visual_range: float = .5

@export_range(0, 2, .001) var mouse_attraction: float = .5
@export_range(0, 1000) var mouse_view_dist: float = 40

@export_range(0, 100) var max_speed: float = 2
@export_range(0, 1, .01) var decay: float = 3
@export var gradient: Gradient


var _mousing_over: bool = false


func _ready():
	# Create a local rendering device.
	rd = RenderingServer.create_local_rendering_device()
	var shader_file := load("res://Boids/boids.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	
	for i in num_agents * 2:
		frame.append(randi_range(0, size - 1))
	for i in num_agents * 2:
		frame.append(0)
		
	var image: Image = Image.create(size, size, true, Image.FORMAT_RGBA8)
	
	while true:                  
		for x in image.get_width():
			for y in image.get_height():
				image.set_pixel(x, y, image.get_pixel(x, y) * decay)
		for i in num_agents:
			image.set_pixel(frame[i], frame[i + num_agents], gradient.sample(abs(frame[i + num_agents * 2] + frame[i + num_agents * 3]) / max_speed) * randf_range(.8, 1.1) * 3)
		sprite.texture = ImageTexture.create_from_image(image)
		
		await get_tree().create_timer(.01).timeout
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
		num_agents,
		coherence,
		separation,
		alignment,
		visual_range,
		max_speed,
		wall_fear,
		slowdown,
		decay,
		sprite.get_local_mouse_position().x + size / 2,
		sprite.get_local_mouse_position().y + size / 2,
		-1 if Input.is_action_pressed("ui_select") else 1,
		mouse_attraction,
		mouse_view_dist if _mousing_over else 0,
		wall_dist,
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
	rd.compute_list_dispatch(compute_list, num_agents, 1, 1)
	rd.compute_list_end()
	
	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()
	
	# Read back the data from the buffer
	return rd.buffer_get_data(buffer).to_float32_array()


func _on_area_2d_mouse_entered():
	_mousing_over = true


func _on_area_2d_mouse_exited():
	_mousing_over = false
