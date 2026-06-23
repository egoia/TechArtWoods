@tool
extends MeshInstance3D
@export var light : DirectionalLight3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_instance_shader_parameter("light_direction", -light.transform.basis.z)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	set_instance_shader_parameter("light_direction", -light.transform.basis.z)
