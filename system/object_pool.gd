class_name ObjectPool

# Generic scene pool. Nodes are marked invisible when returned and reused on
# the next acquire(). The pool grows automatically if all instances are busy.

var _scene: PackedScene
var _nodes: Array[Node] = []


func _init(scene: PackedScene) -> void:
	_scene = scene


# Returns an active node parented to `parent`. Call node.play() after positioning.
func acquire(parent: Node) -> Node:
	for node in _nodes:
		if is_instance_valid(node) and not node.visible:
			if node.get_parent() != parent:
				node.reparent(parent)
			node.visible = true
			return node
	return _make_instance(parent)


# ---- Private ----------------------------------------------------------------

func _make_instance(parent: Node) -> Node:
	var n := _scene.instantiate()
	parent.add_child(n)
	_nodes.append(n)
	# VFX scenes expose a `done` signal — connect it to auto-reclaim.
	if n.has_signal("done"):
		n.done.connect(func() -> void: _reclaim(n))
	return n


func _reclaim(node: Node) -> void:
	if is_instance_valid(node):
		node.visible = false
