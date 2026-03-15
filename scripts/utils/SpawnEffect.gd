extends Node2D

@export var target_color: Color = Color.RED
@export var action: Callable  # ← вот она! Это и есть action

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var ring_effect: GPUParticles2D = $RingEffect
@onready var burst_particles: GPUParticles2D = $BurstParticles

func _ready() -> void:
	# Подключаем сигналы в коде (можно и в инспекторе)
	anim.animation_finished.connect(_on_animation_finished)

	# Запускаем анимацию
	anim.play("spawn_effect")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "spawn_effect":
		queue_free()


# Этот метод вызывается из AnimationPlayer (Call Method Track)
func spawn_now() -> void:
	print("spawn_now вызван в ", global_position)  # для отладки

	# Спавним объект, если action передан
	if action:
		action.call(global_position.x, global_position.y)
	else:
		push_warning("SpawnEffect: action не передан — ничего не заспавнится")
