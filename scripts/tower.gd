extends StaticBody2D

@onready var sprite = $Sprite2D

var hp: float = 100.0
var max_hp: float = 100.0
var def: float = 0.0
var speed: float = 130

var is_dead: bool = false

# Эффекты (Hit Flash)
var hit_tween: Tween

func hit(damage: float):
	if is_dead: return
	
	var actual_damage = calculate_damage(damage)
	hp -= actual_damage
	
	update_visual_color()
	flash_effect()
	
	if hp <= 0:
		die()

func update_visual_color():
	# 1. Получаем коэффициент здоровья от 0.0 до 1.0
	# clamp гарантирует, что значение не выйдет за границы
	var t = clamp(hp / max_hp, 0.0, 1.0)

	# 2. Определяем целевые цвета
	var alive_color = Color("#e91d39") # Твой красный из таблицы (red)
	var dead_color = Color("#303030")  # Твой серый/фоновый (bg) или любой серый

	# Можно также использовать встроенные константы:
	# var dead_color = Color.DARK_GRAY 

	# 3. Интерполируем
	# Если t = 1 (полное ХП) -> будет alive_color
	# Если t = 0 (нет ХП) -> будет dead_color
	sprite.modulate = dead_color.lerp(alive_color, t)

func calculate_damage(dmg: float) -> float:
	if def >= 0:
		return dmg * (100.0 / (100.0 + def))
	else:
		return dmg * (2.0 - 100.0 / (100.0 + def))

func flash_effect():
	if hit_tween: hit_tween.kill()
	hit_tween = create_tween()
	modulate = Color.WHITE * 10 # Яркая вспышка
	hit_tween.tween_property(self, "modulate", Color.WHITE, 0.35)



func die():
	is_dead = true
	queue_free() # Или спавн частиц через G.arena


@export var drag: float = 1.5 # Сопротивление при полете от удара

var being_pushed: bool = false
var push_velocity: Vector2 = Vector2.ZERO

func _ready():
	# Инициализация статов как в твоем коде (Seeker: HP 50%, Speed 30% от базы)
	max_hp = 100.0 * 0.5
	hp = max_hp
	#speed = 75.0 * 0.3
	def = 0.0
