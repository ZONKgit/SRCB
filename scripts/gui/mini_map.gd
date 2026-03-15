extends Control

@export var dungeon: DungeonGenerator
@export var visibility_radius: int = 1

const ROOM_SIZE := Vector2(14, 10)
const ROOM_GAP  := Vector2(2, 2)

const COLOR_VISITED  := Color(0.7, 0.7, 0.7)
const COLOR_CLEARED  := Color(0.3, 0.8, 0.4)
const COLOR_CURRENT  := Color(1.0, 1.0, 1.0)
const COLOR_UNKNOWN  := Color(0.25, 0.25, 0.25)
const COLOR_START    := Color(0.4, 0.6, 1.0)
const COLOR_CONNECTOR := Color(0.5, 0.5, 0.5, 0.8)

const ANIM_SPEED := 6.0  # скорость всех переходов

const COLOR_BACKGROUND := Color(0.0, 0.0, 0.0, 0.45)
const BACKGROUND_PADDING := 10.0  # отступ фона вокруг карты
const BACKGROUND_RADIUS := 6.0    # скругление углов

var visited_rooms: Array[Vector2i] = []


# Для каждой комнаты храним текущий анимированный цвет и прозрачность
var room_colors:   Dictionary = {}  # Vector2i -> Color
var room_alphas:   Dictionary = {}  # Vector2i -> float (0..1, для появления)
var target_colors: Dictionary = {}  # Vector2i -> Color
var target_alphas: Dictionary = {}  # Vector2i -> float

var current_room_display: Vector2  # плавное смещение карты (пока не используем, но задел)

var display_room: Vector2  # текущее анимированное положение камеры карты
var target_room: Vector2   # куда движемся

const CAM_SPEED := 8.0  # скорость смещения карты

func _ready() -> void:
	visited_rooms.append(dungeon.get_start_room_grid())
	dungeon.room_entered.connect(_on_room_entered)
	await dungeon.dungeon_generated
	_init_room_states()
	# Инициализируем позицию камеры карты
	display_room = Vector2(dungeon.get_start_room_grid())
	target_room  = display_room

func _init_room_states() -> void:
	for gy in dungeon.grid_height:
		for gx in dungeon.grid_width:
			if not dungeon.rooms[gy][gx]: continue
			var gp := Vector2i(gx, gy)
			room_colors[gp] = COLOR_UNKNOWN
			room_alphas[gp] = 0.0
			target_colors[gp] = COLOR_UNKNOWN
			target_alphas[gp] = 0.0

	var start := dungeon.get_start_room_grid()
	target_colors[start] = COLOR_START
	target_alphas[start]  = 1.0

	visible_rooms = get_rooms_in_radius(start, visibility_radius)  # ← добавь
	_update_all_targets()

var visible_rooms: Array[Vector2i] = []  # комнаты в радиусе по графу
func _on_room_entered(room: Vector2i) -> void:
	if room not in visited_rooms:
		visited_rooms.append(room)
	target_room = Vector2(room)
	visible_rooms = get_rooms_in_radius(room, visibility_radius)  # ← пересчёт
	_update_all_targets()
	queue_redraw()

func _update_all_targets() -> void:
	var current := dungeon.current_room

	for gp in room_colors.keys():
		if gp not in visible_rooms:
			target_alphas[gp] = 0.0
			continue

		target_alphas[gp] = 1.0
		target_colors[gp] = _get_target_color(gp, current)

func _reveal_neighbors(room: Vector2i) -> void:
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for d in dirs:
		var nb = room + d
		if nb.x < 0 or nb.x >= dungeon.grid_width: continue
		if nb.y < 0 or nb.y >= dungeon.grid_height: continue
		if not dungeon.rooms[nb.y][nb.x]: continue
		target_alphas[nb] = 1.0

func _get_target_color(gp: Vector2i, current: Vector2i) -> Color:
	if gp == current:
		return COLOR_CURRENT
	if dungeon.is_room_cleared(gp):
		return COLOR_CLEARED
	if gp == dungeon.get_start_room_grid():
		return COLOR_START
	if gp in visited_rooms:
		return COLOR_VISITED
	return COLOR_UNKNOWN

func notify_room_cleared(room: Vector2i) -> void:
	# Вызывай это из Arena.gd когда комната зачищена
	if target_colors.has(room):
		target_colors[room] = COLOR_CLEARED

func _process(delta: float) -> void:
	if dungeon.rooms.is_empty(): return

	display_room = display_room.lerp(target_room, CAM_SPEED * delta)

	var current := dungeon.current_room
	var changed := false

	for gp in room_colors.keys():
		if gp in visible_rooms:
			target_colors[gp] = _get_target_color(gp, current)

		var old_color = room_colors[gp] as Color
		var new_color = old_color.lerp(target_colors[gp], ANIM_SPEED * delta)
		if old_color != new_color:
			room_colors[gp] = new_color
			changed = true

		var old_alpha = room_alphas[gp] as float
		var new_alpha = lerp(old_alpha, target_alphas[gp], ANIM_SPEED * delta)
		if abs(old_alpha - new_alpha) > 0.001:
			room_alphas[gp] = new_alpha
			changed = true

	if display_room.distance_to(target_room) > 0.001:
		changed = true

	if changed:
		queue_redraw()

func _draw() -> void:
	if not dungeon: return
	if dungeon.rooms.is_empty(): return
	if dungeon.rooms[0].is_empty(): return

	# Фон
	var bg_rect := Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, COLOR_BACKGROUND)  # простой прямоугольник

	var current := dungeon.current_room
	var step    := ROOM_SIZE + ROOM_GAP
	var center  := size / 2.0

	for gp in room_colors.keys():
		var alpha := room_alphas[gp] as float
		if alpha < 0.01: continue

		var offset := Vector2(gp) * step - display_room * step
		var rect   := Rect2(center + offset - ROOM_SIZE / 2.0, ROOM_SIZE)

		var color: Color = room_colors[gp]
		color.a = alpha
		draw_rect(rect, color)
		_draw_connectors(gp, rect, step)

	draw_circle(center, 2.5, Color(1, 1, 1, 1))

func _draw_connectors(gp: Vector2i, rect: Rect2, step: Vector2) -> void:
	var right := gp + Vector2i.RIGHT
	if right.x < dungeon.grid_width and dungeon.rooms[right.y][right.x]:
		if right in visible_rooms:
			var a := minf(room_alphas.get(gp, 0.0), room_alphas.get(right, 0.0))
			if a > 0.01:
				var c := COLOR_CONNECTOR
				c.a = a
				draw_rect(Rect2(rect.position + Vector2(ROOM_SIZE.x, ROOM_SIZE.y * 0.35),
					Vector2(ROOM_GAP.x, ROOM_SIZE.y * 0.3)), c)

	var down := gp + Vector2i.DOWN
	if down.y < dungeon.grid_height and dungeon.rooms[down.y][down.x]:
		if down in visible_rooms:
			var a := minf(room_alphas.get(gp, 0.0), room_alphas.get(down, 0.0))
			if a > 0.01:
				var c := COLOR_CONNECTOR
				c.a = a
				draw_rect(Rect2(rect.position + Vector2(ROOM_SIZE.x * 0.35, ROOM_SIZE.y),
					Vector2(ROOM_SIZE.x * 0.3, ROOM_GAP.y)), c)

func get_rooms_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited := {}
	var queue: Array = [[center, 0]]
	visited[center] = true

	while not queue.is_empty():
		var entry = queue.pop_front()
		var room: Vector2i = entry[0]
		var depth: int = entry[1]

		result.append(room)

		if depth >= radius:
			continue

		# Проверяем только реальные соединения через двери
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var nb = room + d
			if nb.x < 0 or nb.x >= dungeon.grid_width: continue
			if nb.y < 0 or nb.y >= dungeon.grid_height: continue
			if not dungeon.rooms[nb.y][nb.x]: continue
			if visited.has(nb): continue
			visited[nb] = true
			queue.append([nb, depth + 1])

	return result
