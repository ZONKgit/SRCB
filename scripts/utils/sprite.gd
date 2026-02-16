extends Sprite2D
class_name Sprite

func _process(delta: float) -> void:
	if $shadow != null:
		$shadow.global_position = global_position + Vector2(2, 2)
