class_name Door
extends StaticBody2D

@export var is_open: bool = true :
	set(value):
		is_open = value
		update_visual_and_collision()

@export var locked: bool = false                   # заперта (нужен ключ и т.д.)

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D  # если используешь

var open_texture: Texture2D
var closed_texture: Texture2D

func _ready() -> void:
	# Загрузи текстуры (или используй один AnimatedSprite2D)
	# open_texture = preload("res://assets/door_open.png")
	# closed_texture = preload("res://assets/door_closed.png")

	update_visual_and_collision()

func update_visual_and_collision() -> void:
	if is_open:
		# sprite.texture = open_texture
		if anim: anim.play("open")
		collision.disabled = true
		sprite.visible = false
		# можно добавить light_occluder_2d отключить и т.д.
	else:
		# sprite.texture = closed_texture
		if anim: anim.play("closed")
		collision.disabled = false
		sprite.visible = true

# Вызывай эти методы из другого кода
func open() -> void:
	if locked: return
	is_open = true

func close() -> void:
	is_open = false

func lock() -> void:
	locked = true
	close()

func unlock() -> void:
	locked = false
	# можно сразу открыть, если хочешь
	# open()
