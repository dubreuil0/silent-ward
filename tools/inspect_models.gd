extends SceneTree
## Geliştirme aracı: indirilen modellerin boyutlarını yazdırır.
## godot --headless --path . --script res://tools/inspect_models.gd

func _init() -> void:
	var dir := DirAccess.open("res://assets/models")
	for id in dir.get_directories():
		var path := "res://assets/models/%s/%s.gltf" % [id, id]
		var ps := load(path) as PackedScene
		if ps == null:
			print("FAIL ", id)
			continue
		var inst := ps.instantiate() as Node3D
		root.add_child(inst)
		var box := AABB()
		var first := true
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var b := mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		print("%s pos=%s size=%s" % [id, box.position, box.size])
		inst.queue_free()
	quit()
