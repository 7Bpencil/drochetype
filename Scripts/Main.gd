class_name Main extends Node

@export_group("Screens")
@export var screen_main: ScreenMain
@export var screen_typing: ScreenTyping
@export var screen_result: ScreenResult

var english_1k: PackedStringArray

func _ready() -> void:
    screen_main.visible = true
    screen_typing.visible = false
    screen_result.visible = false

    var english_1k_file = FileAccess.open("res://Data/engilsh_1k.txt", FileAccess.READ)
    var english_1k_file_content = english_1k_file.get_as_text()
    english_1k = english_1k_file_content.split("\r\n")

    screen_main.start_typing.connect(_on_start)
    screen_typing.show_typing_result.connect(_on_end)

func _on_start():
    screen_main.visible = false
    screen_typing.visible = true
    var new_test_words = _generate_new_test(english_1k, 20)
    screen_typing.start_test(new_test_words)

func _generate_new_test(all_words: PackedStringArray, words_count: int) -> PackedStringArray:
    var result: Array[String] = []
    result.resize(words_count)
    for i in range(words_count):
        var random_index = randi_range(0, all_words.size() - 1)
        var random_word = all_words[random_index]
        result[i] = random_word
    return result

func _on_end(result: TypingResult):
    screen_typing.visible = false
    screen_result.visible = true
    screen_result.show_result(result)
