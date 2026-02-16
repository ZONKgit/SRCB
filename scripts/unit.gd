extends CharacterBody2D
class_name Unit

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

func _physics_process(dt: float) -> void:
	if being_pushed:
		process_push(dt)
	else:
		process_ai(dt)
	
	# move_and_collide возвращает объект KinematicCollision2D при ударе
	var collision = move_and_collide(velocity * dt)
	
	if collision:
		var collider = collision.get_collider()
		
		# 1. Столкновение с игроком или его хвостом
		if collider == G.leader or (collider in G.leader.followers):
			# Отлетаем от игрока
			var push_angle = (global_position - collider.global_position).angle()
			push(randf_range(25, 35), push_angle)
			
			# Наносим урон игроку/хвосту и получаем сами (как в оригинале)
			if collider.has_method("hit"):
				collider.hit(20)
			self.hit(20)

		# 2. Столкновение с другим юнитом (цепная реакция)
		elif collider is Unit:
			# Если один из нас в состоянии полета (being_pushed), передаем импульс
			if self.being_pushed or collider.being_pushed:
				var push_angle = (global_position - collider.global_position).angle()
				push(randf_range(15, 25), push_angle)
				# Можно добавить микро-урон при столкновении врагов друг с другом
				self.hit(2) 

		# 3. Столкновение со стеной (Bounce)
		else:
			# Используем нормаль столкновения для отскока (как в твоем первом Godot коде)
			velocity = velocity.bounce(collision.get_normal())
			# Если мы летели от удара, гасим часть скорости об стену
			if being_pushed:
				push_velocity = push_velocity.bounce(collision.get_normal()) * 0.6

# --- Логика ИИ (Steering Behaviors) ---
func process_ai(dt: float):
	var target = G.leader
	if not target: return
	
	# 1. Seek (Преследование)
	var desired_velocity = global_position.direction_to(target.global_position) * speed
	
	# 3. Wander (Блуждание - небольшая случайность)
	var wander = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 80.0
	
	velocity = velocity.lerp(desired_velocity + wander, 5.0 * dt)
	
	# Поворот в сторону движения
	if velocity.length() > 10:
		rotation = lerp_angle(rotation, velocity.angle(), 0.1)

# --- Логика получения пинка (Push) ---
func push(force: float, angle: float):
	being_pushed = true
	push_velocity = Vector2.from_angle(angle) * force * 10.0
	
	# Закручиваем спрайт (визуальный эффект)
	var t = create_tween()
	t.tween_property(self, "rotation", rotation + PI*4, 0.5)

func process_push(dt: float):
	velocity = push_velocity
	# Применяем Damping (сопротивление среды)
	push_velocity = push_velocity.move_toward(Vector2.ZERO, drag * 500.0 * dt)
	
	if push_velocity.length() < 25.0:
		being_pushed = false
