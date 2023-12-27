extends Control

@onready var fps_counter = $fps_counter

func _process(_delta):
	fps_counter.text = str(Engine.get_frames_per_second())
