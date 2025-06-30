extends Node

class_name Main

@export_group("Screens")
@export var screen_main: ScreenMain
@export var screen_typing: ScreenTyping
@export var screen_result: ScreenResult

func _ready() -> void:
    screen_main.visible = true
    screen_typing.visible = false
    screen_result.visible = false
    screen_main.start_typing.connect(_on_start)
    screen_typing.show_typing_result.connect(_on_end)

func _on_start():
    screen_main.visible = false
    screen_typing.visible = true
    screen_typing.start_test()

func _on_end(test_duration_msec: int, goal_text_characters: int, mistakes_count: int):
    screen_typing.visible = false
    screen_result.visible = true
    screen_result.show_result(test_duration_msec, goal_text_characters, mistakes_count)
