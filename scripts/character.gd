extends CharacterBody2D

@export var speed: float = 120.0
@export var is_leader: bool = false

var previous_positions: Array[Dictionary] = []  # [{pos: Vector2, rot: float}]
var followers: Array[Node2D] = []

@onready var timer: Timer = $Timer  # добавь Timer в сцену, установи wait_time = 0.01, autostart = true

func _ready() -> void:
	if is_leader and timer:
		timer.timeout.connect(_on_timer_timeout)

func _physics_process(delta: float) -> void:
	if not is_leader:
		return  # followers двигаются через previous_positions

	# Движение лидера (твой код отскока остаётся)
	if Input.is_key_pressed(KEY_LEFT):
		rotation -= 1.8 * PI * delta
	if Input.is_key_pressed(KEY_RIGHT):
		rotation += 1.8 * PI * delta
	
	var original_velocity = Vector2(cos(rotation), sin(rotation)) * speed
	velocity = original_velocity
	move_and_slide()

	if get_slide_collision_count() > 0:
		var collision = get_slide_collision(0)
		velocity = original_velocity.bounce(collision.get_normal())
		rotation = velocity.angle()

func _on_timer_timeout() -> void:
	if not is_leader:
		return

	previous_positions.insert(0, { "pos": global_position, "rot": rotation })

	# Ограничение длины (как в SNKRX — 256 хватит с запасом)
	if previous_positions.size() > 300:
		previous_positions.pop_back()
	
	# Обновляем followers
	_update_followers()

func _update_followers() -> void:
	for i in range(followers.size()):
		var follower = followers[i]
		var follower_index = i + 1  # 1,2,3,...

		# Задержка как в SNKRX: чем дальше — тем больше кадров назад
		# v ≈ 120 → 0.1 * 120 = 12 → каждый сегмент отстаёт примерно на 12*индекс кадров
		var delay_frames = round(speed * 0.05) * follower_index

		var idx = delay_frames
		if idx < previous_positions.size():
			var data = previous_positions[idx]
			follower.global_position = data.pos
			follower.rotation = data.rot

func _draw() -> void:
	var rect_size = 9
	var rect := Rect2(-rect_size/2, -rect_size/2, rect_size, rect_size)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(3)
	style.corner_detail = 5
	draw_style_box(style, rect)


func add_follower() -> void:
	var segment_scene = preload("res://scenes/character.tscn")  # предполагается, что у сегмента тоже есть _draw()
	var new_segment = segment_scene.instantiate()


	G.arena.add_child(new_segment)
	followers.append(new_segment)
	
	# ставим примерно на позицию хвоста или чуть позади
	if followers.size() == 1:
		new_segment.global_position = global_position - Vector2(cos(rotation), sin(rotation))
	else:
		var last = followers[followers.size() - 2]
		new_segment.global_position = last.global_position
