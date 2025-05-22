extends Node

@export var button:Button

func _ready()->void:
	button.pressed.connect(pressed)

func pressed()->void:
	Log.stop_session()
	get_tree().quit()
