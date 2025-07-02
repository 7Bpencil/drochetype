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

func _on_start():
    var original_text: String = "rifle visual furl quality plus else cultural complex role directly cell athlete handful yell small terrible blue scandal telephone newly"
    var words = original_text.split(" ")

    screen_main.visible = false
    screen_typing.visible = true
    screen_typing.start_test(words)

func _on_end(result: TypingResult):
    screen_typing.visible = false
    screen_result.visible = true
    screen_result.show_result(result)
