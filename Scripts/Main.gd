class_name Main extends Node


@export_group("Screens")
@export var screen_main: ScreenMain
@export var screen_typing: ScreenTyping
@export var screen_result: ScreenResult


func _ready() -> void:
    screen_main.show()
    screen_typing.hide()
    screen_result.hide()

    screen_main.start_typing.connect(_on_start)
    screen_main.restart_test_with_new_config.connect(_on_restart)
    screen_typing.show_typing_result.connect(_on_end)
    screen_typing.restart_test.connect(_on_restart)

    var typing_data = _load_typing_data()
    var typing_config = _load_typing_config()

    screen_typing.set_typing_data(typing_data)
    screen_main.set_typing_config(typing_config)
    screen_main.after_init()


func _load_typing_data() -> TypingData:
    var typing_data = TypingData.new()
    typing_data.english_words_map = {
        TypingData.WordsRarity.VeryCommon : _load_language("res://Data/english_1k.txt"),
        TypingData.WordsRarity.Common     : _load_language("res://Data/english_1k.txt"),
        TypingData.WordsRarity.Rare       : _load_language("res://Data/english_1k.txt"),
        TypingData.WordsRarity.VeryRare   : _load_language("res://Data/english_450k.txt"),
    }
    return typing_data


func _load_language(path: String) -> PackedStringArray:
    var words_file = FileAccess.open(path, FileAccess.READ)
    var words_file_content = words_file.get_as_text()
    var first_few_words = words_file_content.left(50) # lets hope there wont be 50 char long words...
    if first_few_words.contains("\r\n"):
        return words_file_content.split("\r\n")
    if first_few_words.contains("\n"):
        return words_file_content.split("\n")
    return []


func _load_typing_config() -> TypingConfig:
    var typing_config = TypingConfig.new()
    typing_config.words_rarity = TypingData.WordsRarity.VeryCommon
    typing_config.words_count = 20
    return typing_config


func _on_start(typing_config: TypingConfig):
    screen_main.show()
    screen_typing.show()
    screen_result.hide()
    screen_typing.start_test(typing_config)


func _on_restart(typing_config: TypingConfig):
    screen_result.hide()
    screen_typing.start_test(typing_config)


func _on_end(result: TypingResult):
    screen_result.show()
    screen_result.show_result(result)
