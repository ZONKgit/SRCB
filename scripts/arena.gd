extends Node2D
class_name Arena

@onready var Seeker: PackedScene = preload("res://scenes/seeker.tscn")
@onready var dungeon = $DungeonGenerator
@onready var minimap: Control = $CanvasLayer/MiniMap

var enemies_alive: int = 0
var active_room: Vector2i = Vector2i(-1, -1)
var pending_lock_room: Vector2i = Vector2i(-1, -1)  # комната ожидающая закрытия

func _init() -> void:
	G.arena = self

func _ready() -> void:
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()

	dungeon = $DungeonGenerator
	dungeon.room_entered.connect(_on_room_entered)

func _process(delta: float) -> void:
	# Ждём пока вся змея войдёт в комнату
	if pending_lock_room != Vector2i(-1, -1):
		if dungeon.is_whole_snake_in_room(pending_lock_room):
			dungeon.set_room_doors_open(pending_lock_room, false)
			spawn_enemies_in_player_room(5)
			pending_lock_room = Vector2i(-1, -1)

func _on_room_entered(room: Vector2i) -> void:
	if room == dungeon.get_start_room_grid():
		return
	if dungeon.is_room_cleared(room):  # уже зачищена — ничего не делаем
		return

	active_room = room
	pending_lock_room = room

func on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive <= 0:
		dungeon.mark_room_cleared(active_room)  # запоминаем
		dungeon.set_room_doors_open(active_room, true)
		minimap.notify_room_cleared(active_room)

func spawn_enemies_in_player_room(n: int = 1) -> void:
	var room_center = dungeon.get_room_world_center(active_room)

	var tile_size: Vector2 = dungeon.tilemap_layer.tile_set.tile_size
	var inner_half_w = (dungeon.room_width  - 3) * tile_size.x / 2.0
	var inner_half_h = (dungeon.room_height - 3) * tile_size.y / 2.0

	var group_pos := Vector2(
		room_center.x + randf_range(-inner_half_w, inner_half_w),
		room_center.y + randf_range(-inner_half_h, inner_half_h)
	)

	var effect_scene = preload("res://scenes/subs/SpawnEffect.tscn")
	enemies_alive = n

	for i in n:
		await get_tree().create_timer(i * 0.1).timeout

		var spawn_pos := group_pos + Vector2(randf_range(-16, 16), randf_range(-16, 16))

		var effect = effect_scene.instantiate()
		effect.position = spawn_pos
		effect.target_color = Color(0.9, 0.2, 0.2)
		effect.action = func(x: float, y: float):
			var enemy = Seeker.instantiate()
			enemy.position = Vector2(x, y)
			enemy.rotation = randf_range(0, TAU)
			# Подписываемся на смерть врага
			enemy.died.connect(on_enemy_died)
			add_child(enemy)
		add_child(effect)
