class_name Main extends Node


@export_group("Screens")
@export var screen_main: ScreenMain
@export var screen_typing: ScreenTyping
@export var screen_result: ScreenResult


func _ready() -> void:
    screen_main.show()
    screen_typing.hide()
    screen_result.hide()

    screen_main.generate_new_test.connect(_on_restart)
    screen_typing.show_test_result.connect(_on_end)
    screen_typing.generate_new_test.connect(_on_restart)
    screen_typing.reset_current_test.connect(_on_reset)

    var typing_data = TypingData.load()
    var typing_config = TypingConfig.load()

    screen_typing.set_typing_data(typing_data)
    screen_main.set_data(typing_data, typing_config)
    _on_start(typing_config)


func _on_start(typing_config: TypingConfig):
    screen_main.show()
    screen_typing.show()
    screen_result.hide()
    screen_typing.start_test(typing_config)


func _on_restart(typing_config: TypingConfig):
    screen_result.hide()
    screen_typing.start_test(typing_config)


func _on_reset():
    screen_result.hide()
    screen_typing.reset_test()


func _on_end(result: TypingResult):
    screen_result.show()
    screen_result.show_result(result)
