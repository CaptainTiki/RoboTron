extends CPUParticles3D

# Persistent wound effect at a part-separation point.
# Used by both wound_spark.tscn (sparks) and damage_smoke.tscn (smoke).
# Material and appearance are controlled entirely by the scene file.
# Freed automatically when the parent enemy node dies.

func _ready() -> void:
	_emphasize_visibility()
	restart()
	emitting = true


func _emphasize_visibility() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = m
