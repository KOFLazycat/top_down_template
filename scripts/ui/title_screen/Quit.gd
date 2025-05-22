class_name Quit
extends Node

@export var button:Button

func _ready()->void:
	button.pressed.connect(pressed, CONNECT_ONE_SHOT)

func pressed()->void:
	Log.stop_session()
	get_tree().quit()
