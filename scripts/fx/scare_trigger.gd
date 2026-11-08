class_name ScareTrigger
extends Area3D
## Oyuncu girdiğinde bir kez çalışan tetikleyici.

var action: Callable
var once := true
var condition: Callable

var _fired := false


func setup(center: Vector3, size: Vector3, act: Callable, cond: Callable = Callable()) -> void:
	position = center + Vector3.UP * size.y * 0.5
	action = act
	condition = cond
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _fired or body != Game.player:
		return
	if condition.is_valid() and not condition.call():
		return
	_fired = once
	action.call()
