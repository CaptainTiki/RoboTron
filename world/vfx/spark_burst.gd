extends CPUParticles3D

# One-shot burst of sparks at a piece-detach point.
# Pool auto-reclaims via the `done` signal when particles finish.

signal done()


func _ready() -> void:
	one_shot  = true
	emitting  = false
	_apply_billboard_mat(false)
	finished.connect(func() -> void: done.emit())


func _apply_billboard_mat(transparent: bool) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode            = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = m


func play() -> void:
	restart()
	emitting = true
