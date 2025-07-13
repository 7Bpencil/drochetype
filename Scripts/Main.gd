class_name Main extends Node


@export var screen_main: ScreenMain
@export var screen_typing: ScreenTyping
@export var screen_result: ScreenResult


var typing_data: TypingData
var typing_config: TypingConfig


func _ready() -> void:
    screen_main.show()
    screen_typing.hide()
    screen_result.hide()

    screen_main.generate_new_test.connect(_on_restart)
    screen_typing.show_test_result.connect(_on_end)
    screen_typing.generate_new_test.connect(_on_restart)
    screen_typing.reset_current_test.connect(_on_reset)
    screen_typing.update_letter_stats.connect(screen_main.update_letter_stats)

    typing_data = TypingData.load()
    typing_config = TypingConfig.load()

    screen_main.set_data(typing_data, typing_config)
    screen_typing.set_data(typing_data, typing_config)
    _on_start()


func _on_start():
    screen_main.show()
    screen_typing.show()
    screen_result.hide()
    screen_typing.start_test()


func _on_restart():
    screen_result.hide()
    screen_typing.start_test()


func _on_reset():
    screen_result.hide()
    screen_typing.reset_test()


func _on_end(result: TypingResult):
    screen_result.show()
    screen_result.show_result(result)


func _notification(what):
    if (
        what == NOTIFICATION_WM_CLOSE_REQUEST or
        what == NOTIFICATION_APPLICATION_PAUSED or
        what == NOTIFICATION_WM_GO_BACK_REQUEST
    ):
        typing_config.save()
