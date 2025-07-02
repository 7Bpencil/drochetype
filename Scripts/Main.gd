class_name Main extends Node


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
    screen_typing.restart_test.connect(_on_restart)

    screen_main.after_init()


func _on_start():
    screen_main.visible = true
    screen_typing.visible = true
    screen_result.visible = false
    screen_typing.start_test()


func _on_restart():
    screen_result.visible = false
    screen_typing.start_test()


func _on_end(result: TypingResult):
    screen_result.visible = true
    screen_result.show_result(result)
