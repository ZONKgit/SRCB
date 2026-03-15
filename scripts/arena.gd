extends Node2D
class_name Arena

@onready var Seeker: PackedScene = preload("res://scenes/seeker.tscn")

func _init() -> void:
	G.arena = self

func _ready() -> void:
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		spawn_enemies_in_player_room(5)

func spawn_enemies_in_player_room(n: int = 1) -> void:
	var dungeon = $DungeonGenerator
	var room_grid = dungeon.get_player_room_grid()
	var room_center = dungeon.get_room_world_center(room_grid)

	var tile_size: Vector2 = dungeon.tilemap_layer.tile_set.tile_size
	var inner_half_w = (dungeon.room_width  - 3) * tile_size.x / 2.0
	var inner_half_h = (dungeon.room_height - 3) * tile_size.y / 2.0

	# Одна случайная точка для всей кучки
	var group_pos := Vector2(
		room_center.x + randf_range(-inner_half_w, inner_half_w),
		room_center.y + randf_range(-inner_half_h, inner_half_h)
	)

	var effect_scene = preload("res://scenes/subs/SpawnEffect.tscn")

	for i in n:
		await get_tree().create_timer(i * 0.1).timeout

		# Небольшой разброс вокруг точки кучки
		var spawn_pos := group_pos + Vector2(randf_range(-16, 16), randf_range(-16, 16))

		var effect = effect_scene.instantiate()
		effect.position = spawn_pos
		effect.target_color = Color(0.9, 0.2, 0.2)
		effect.action = func(x: float, y: float):
			var enemy = Seeker.instantiate()
			enemy.position = Vector2(x, y)
			enemy.rotation = randf_range(0, TAU)
			add_child(enemy)
		add_child(effect)
