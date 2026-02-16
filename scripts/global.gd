extends Node

var arena: Arena = null
var leader: Char = null

var sounds = {
	"collide_wall" : "res://assets/sounds/Wood Heavy 5.ogg",
	"pop1" : "res://assets/sounds/Pop sounds 10.ogg"
}

var colors = {
	"white": Color(1, 1, 1, 1),
	"black": Color(0, 0, 0, 1),
	"bg": Color("#303030"),
	"fg": Color("#dadada"),
	"fg_alt": Color("#b0a89f"),
	"yellow": Color("#facf00"),
	"orange": Color("#f07021"),
	"blue": Color("#019bd6"),
	"green": Color("#8bbf40"),
	"red": Color("#e91d39"),
	"purple": Color("#8e559e"),
	"blue2": Color("#4778ba"),
	"yellow2": Color("#f59f10"),
}

func play_sound(path, pitch, volume) -> void:
	var sound_player = AudioStreamPlayer.new()
	sound_player.stream = load(path)
	sound_player.pitch_scale = pitch
	sound_player.volume_db = volume
	sound_player.finished.connect(sound_player.queue_free)
	arena.add_child(sound_player)
	sound_player.play()
