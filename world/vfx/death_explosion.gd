extends CPUParticles3D

# Large one-shot explosion burst on enemy death (and glory kills).
# The pool reclaims via `done` when particles finish.

signal done()


func _ready() -> void:
	one_shot  = true
	emitting  = false
	_apply_billboard_mat()
	finished.connect(func() -> void: done.emit())


func _apply_billboard_mat() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode             = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	material_override = m


func play() -> void:
	restart()
	emitting = true
