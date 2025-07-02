class_name ScreenMain extends Node

@export var start_button: Button

signal start_typing

func _ready() -> void:
    start_button.pressed.connect(_on_button_start)

func _on_button_start():
    start_typing.emit()
