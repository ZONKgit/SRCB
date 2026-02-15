extends Node2D
class_name Arena

func _init() -> void:
	G.arena = self

func _ready() -> void:
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
	$CharacterBody2D.add_follower()
