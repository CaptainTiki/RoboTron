extends Node3D

# Continuous low sparks and rising smoke on a grounded debris piece.
# Plays for DURATION seconds then signals the pool to reclaim.

signal done()

const DURATION := 5.5

@onready var _sparks: CPUParticles3D = $Sparks
@onready var _smoke:  CPUParticles3D = $Smoke

var _timer: float = 0.0
var _running: bool = false


func _ready() -> void:
	_sparks.material_override = _make_mat(false)
	_smoke.material_override  = _make_mat(true)


func _make_mat(transparent: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode             = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func play() -> void:
	_timer   = DURATION
	_running = true
	_sparks.restart()
	_smoke.restart()
	_sparks.emitting = true
	_smoke.emitting  = true


func _process(delta: float) -> void:
	if not _running:
		return
	_timer -= delta
	if _timer <= 0.8:
		# Taper off: stop emitting new particles and let the last ones die
		_sparks.emitting = false
		_smoke.emitting  = false
	if _timer <= 0.0:
		_running = false
		done.emit()
