extends CPUParticles3D

# Persistent electric spark at a part-separation point.
# Parented directly to the surviving robot part — no pooling needed.
# Freed automatically when the parent part detaches or the enemy dies.

func _ready() -> void:
	emitting = true
	var m := StandardMaterial3D.new()
	m.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode             = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	material_override = m
