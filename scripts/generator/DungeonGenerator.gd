# DungeonGenerator.gd
# Подходит для Godot 4.3 / 4.4 с TileMapLayer
# Генерация комнат в стиле The Binding of Isaac
class_name DungeonGenerator
extends Node2D

signal dungeon_generated

@export var tilemap_layer: TileMapLayer

# === НАСТРОЙКИ ===
@export_group("Размеры сетки комнат")
@export var grid_width: int = 8
@export var grid_height: int = 6

@export_group("Размер одной комнаты (в тайлах)")
@export var room_width: int = 25     # лучше нечётное
@export var room_height: int = 15    # лучше нечётное

@export_group("Тайлы (из вашего TileSet)")
@export var source_id: int = 0                  # обычно 0, если один источник
@export var floor_atlas: Vector2i = Vector2i(-1, -1)
@export var wall_atlas:  Vector2i = Vector2i(0, 0)

@export_group("Двери / проходы")
@export var door_size: int = 3                  # ширина/высота прохода в тайлах



# Внутренние данные
var rooms: Array = []  # 2D массив bool
var start_room_grid_pos: Vector2i = Vector2i.ZERO

var current_room: Vector2i = Vector2i(-1, -1)
var room_doors: Dictionary = {}  # Vector2i -> Array[Door]

var cleared_rooms: Array[Vector2i] = []

signal room_entered(room_grid: Vector2i)

func _ready() -> void:
	await get_tree().process_frame     # ждём один кадр
	generate_dungeon()
	G.leader.get_node("Camera2D").position_smoothing_enabled = false
	G.leader.global_position = get_start_world_position()
	G.leader.get_node("Camera2D").position_smoothing_enabled = true

func _process(_delta: float) -> void:
	var center = get_room_world_center(get_player_room_grid())
	$"../Camera2D".global_position = center

	# Отслеживание смены комнаты
	var room = get_player_room_grid()
	if room != current_room:
		current_room = room
		room_entered.emit(current_room)

func generate_dungeon() -> void:
	if not tilemap_layer:
		push_error("TileMapLayer не назначен в инспекторе!")
		return
	
	clear_map()
	generate_room_grid_layout()
	place_floors()
	place_walls()
	carve_doors()
	place_door_nodes()
	merge_shared_walls()

	print("Генерация завершена. Комнат: ", count_rooms())
	dungeon_generated.emit()

func clear_map() -> void:
	tilemap_layer.clear()

# ────────────────────────────────────────────────
# 1. Генерация расположения комнат (связный граф)
# ────────────────────────────────────────────────
func generate_room_grid_layout() -> void:
	rooms.clear()
	for y in grid_height:
		var row: Array[bool] = []
		row.resize(grid_width)
		row.fill(false)
		rooms.append(row)

	start_room_grid_pos = Vector2i(grid_width / 2, grid_height / 2)
	rooms[start_room_grid_pos.y][start_room_grid_pos.x] = true

	var target := randi_range(10, 16)
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

	# Frontier — список клеток, куда ещё можно расширяться
	var frontier: Array[Vector2i] = [start_room_grid_pos]

	while count_rooms() < target and not frontier.is_empty():
		# Берём случайную клетку из frontier (не обязательно последнюю)
		var idx = randi() % frontier.size()
		var current = frontier[idx]

		# Собираем свободных соседей
		var free_neighbors: Array[Vector2i] = []
		for d in dirs:
			var nx = current.x + d.x
			var ny = current.y + d.y
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if not rooms[ny][nx]:
					# Проверяем, что у соседа не больше 1 уже занятого соседа
					# — это не даёт комнатам "слипаться" в квадраты
					var occupied_neighbors := 0
					for d2 in dirs:
						var nnx = nx + d2.x
						var nny = ny + d2.y
						if nnx >= 0 and nnx < grid_width and nny >= 0 and nny < grid_height:
							if rooms[nny][nnx]:
								occupied_neighbors += 1
					if occupied_neighbors <= 1:
						free_neighbors.append(Vector2i(nx, ny))

		if free_neighbors.is_empty():
			# Эта клетка исчерпана — убираем из frontier
			frontier.remove_at(idx)
			continue

		# Ставим случайного соседа
		var chosen = free_neighbors[randi() % free_neighbors.size()]
		rooms[chosen.y][chosen.x] = true
		frontier.append(chosen)

		# Иногда убираем текущую из frontier — создаёт "ветвление"
		if randf() < 0.4:
			frontier.remove_at(idx)
	

func count_rooms() -> int:
	var c := 0
	for row in rooms:
		for v in row:
			if v: c += 1
	return c

# ────────────────────────────────────────────────
# Вспомогательные функции
# ────────────────────────────────────────────────
func get_room_pixel_offset(grid_pos: Vector2i) -> Vector2i:
	return Vector2i(grid_pos.x * (room_width - 1), grid_pos.y * (room_height - 1))

# ────────────────────────────────────────────────
# 2. Полы внутри комнат
# ────────────────────────────────────────────────
func place_floors() -> void:
	for y in grid_height:
		for x in grid_width:
			if not rooms[y][x]: continue
			
			var offset = get_room_pixel_offset(Vector2i(x, y))
			
			for tx in range(1, room_width - 1):
				for ty in range(1, room_height - 1):
					tilemap_layer.set_cell(
						offset + Vector2i(tx, ty),
						source_id,
						floor_atlas
					)

# ────────────────────────────────────────────────
# 3. Стены по периметру каждой комнаты
# ────────────────────────────────────────────────
func place_walls() -> void:
	for gy in grid_height:
		for gx in grid_width:
			if not rooms[gy][gx]: continue

			var offset = get_room_pixel_offset(Vector2i(gx, gy))

			# Верх + низ — всегда
			for tx in room_width:
				tilemap_layer.set_cell(offset + Vector2i(tx, 0),                 source_id, wall_atlas)
				tilemap_layer.set_cell(offset + Vector2i(tx, room_height - 1), source_id, wall_atlas)
			
			# Лево + право — всегда
			for ty in room_height:
				tilemap_layer.set_cell(offset + Vector2i(0, ty),                 source_id, wall_atlas)
				tilemap_layer.set_cell(offset + Vector2i(room_width - 1, ty), source_id, wall_atlas)

func merge_shared_walls() -> void:
	# Вертикальные стыки (между комнатами слева-справа)
	for gy in grid_height:
		for gx in range(grid_width - 1):
			if not (rooms[gy][gx] and rooms[gy][gx + 1]):
				continue  # нет двух соседних комнат → пропускаем

			var left_offset  = get_room_pixel_offset(Vector2i(gx, gy))
			var wall_x = left_offset.x + room_width - 1  # позиция "общей" стены
			
			for ty in room_height:
				var pos = Vector2i(wall_x, left_offset.y + ty)

				# Если это уже пол (дверь) — оставляем как есть
				if tilemap_layer.get_cell_atlas_coords(pos) == floor_atlas:
					continue

				# Иначе ставим стену (перезаписываем, если там была двойная)
				tilemap_layer.set_cell(pos, source_id, wall_atlas)

	# Горизонтальные стыки (между комнатами сверху-снизу)
	for gx in grid_width:
		for gy in range(grid_height - 1):
			if not (rooms[gy][gx] and rooms[gy + 1][gx]):
				continue

			var upper_offset = get_room_pixel_offset(Vector2i(gx, gy))
			var wall_y = upper_offset.y + room_height - 1
			
			for tx in room_width:
				var pos = Vector2i(upper_offset.x + tx, wall_y)

				if tilemap_layer.get_cell_atlas_coords(pos) == floor_atlas:
					continue

				tilemap_layer.set_cell(pos, source_id, wall_atlas)

# ────────────────────────────────────────────────
# 4. Прорезание проходов (дверей)
# ────────────────────────────────────────────────
func carve_doors() -> void:
	# Горизонтальные (право ←→ лево)
	for y in grid_height:
		for x in range(grid_width - 1):
			if rooms[y][x] and rooms[y][x + 1]:
				var left_offset  = get_room_pixel_offset(Vector2i(x, y))
				var right_offset = get_room_pixel_offset(Vector2i(x + 1, y))
				
				var door_y = (room_height - door_size) / 2
				
				for dy in door_size:
					var ty = door_y + dy
					# убираем стену справа от левой комнаты
					tilemap_layer.set_cell(
						left_offset + Vector2i(room_width - 1, ty),
						source_id, floor_atlas
					)
					# убираем стену слева от правой комнаты
					tilemap_layer.set_cell(
						right_offset + Vector2i(0, ty),
						source_id, floor_atlas
					)
	
	# Вертикальные (низ ↑↓ верх)
	for x in grid_width:
		for y in range(grid_height - 1):
			if rooms[y][x] and rooms[y + 1][x]:
				var upper_offset = get_room_pixel_offset(Vector2i(x, y))
				var lower_offset = get_room_pixel_offset(Vector2i(x, y + 1))
				
				var door_x = (room_width - door_size) / 2
				
				for dx in door_size:
					var tx = door_x + dx
					tilemap_layer.set_cell(
						upper_offset + Vector2i(tx, room_height - 1),
						source_id, floor_atlas
					)
					tilemap_layer.set_cell(
						lower_offset + Vector2i(tx, 0),
						source_id, floor_atlas
					)


func place_door_nodes() -> void:
	var door_scene = preload("res://scenes/Door.tscn")

	for gy in grid_height:
		for gx in range(grid_width - 1):
			if rooms[gy][gx] and rooms[gy][gx + 1]:
				var left_offset = get_room_pixel_offset(Vector2i(gx, gy))
				var door_pos = Vector2i(left_offset.x + room_width - 1, left_offset.y + (room_height - 1) / 2)

				var door = door_scene.instantiate() as Door
				add_child(door)
				door.global_position = tilemap_layer.map_to_local(door_pos)
				door.rotation_degrees = 90

				_register_door(door, Vector2i(gx, gy))
				_register_door(door, Vector2i(gx + 1, gy))

	for gx in grid_width:
		for gy in range(grid_height - 1):
			if rooms[gy][gx] and rooms[gy + 1][gx]:
				var upper_offset = get_room_pixel_offset(Vector2i(gx, gy))
				var door_pos = Vector2i(upper_offset.x + (room_width - 1) / 2, upper_offset.y + room_height - 1)

				var door = door_scene.instantiate() as Door
				add_child(door)
				door.global_position = tilemap_layer.map_to_local(door_pos)

				_register_door(door, Vector2i(gx, gy))
				_register_door(door, Vector2i(gx, gy + 1))

func _register_door(door: Door, room: Vector2i) -> void:
	if not room_doors.has(room):
		room_doors[room] = []
	room_doors[room].append(door)


# ────────────────────────────────────────────────
# Полезные методы для игры
# ────────────────────────────────────────────────
func get_start_room_grid() -> Vector2i:
	return start_room_grid_pos

func get_start_world_position() -> Vector2:
	var offset = get_room_pixel_offset(start_room_grid_pos)
	var center_tile = offset + Vector2i(room_width / 2, room_height / 2)
	return tilemap_layer.map_to_local(center_tile)

func get_player_room_grid() -> Vector2i:
	var tile_pos = tilemap_layer.local_to_map(G.leader.global_position)
	var room_x = tile_pos.x / (room_width - 1)
	var room_y = tile_pos.y / (room_height - 1)
	return Vector2i(room_x, room_y)

func get_room_world_center(grid_pos: Vector2i) -> Vector2:
	var offset = get_room_pixel_offset(grid_pos)
	var center_tile = offset + Vector2i(room_width / 2, room_height / 2)
	return tilemap_layer.map_to_local(center_tile)

func set_room_doors_open(room: Vector2i, open: bool) -> void:
	if not room_doors.has(room): return
	for door in room_doors[room]:
		if open:
			door.open()
		else:
			door.close()


func is_whole_snake_in_room(room: Vector2i, margin: float = 8.0) -> bool:
	var tile_size: Vector2 = tilemap_layer.tile_set.tile_size
	var room_center = get_room_world_center(room)
	
	# Границы внутренней области комнаты с отступом
	var half_w = (room_width  - 2) * tile_size.x / 2.0 - margin
	var half_h = (room_height - 2) * tile_size.y / 2.0 - margin
	
	var bounds = Rect2(
		room_center - Vector2(half_w, half_h),
		Vector2(half_w, half_h) * 2.0
	)
	
	if not bounds.has_point(G.leader.global_position):
		return false
	
	for follower in G.leader.followers:
		if not bounds.has_point(follower.global_position):
			return false
	
	return true

func is_room_cleared(room: Vector2i) -> bool:
	return room in cleared_rooms

func mark_room_cleared(room: Vector2i) -> void:
	if room not in cleared_rooms:
		cleared_rooms.append(room)

# Пример использования:
# func spawn_player(player: Node2D) -> void:
#     player.global_position = get_start_world_position()
