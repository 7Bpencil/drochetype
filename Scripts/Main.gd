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

    var typing_data = _load_typing_data()
    var typing_config = _load_typing_config()

    screen_typing.set_typing_data(typing_data)
    screen_main.set_typing_config(typing_config)
    _on_start(typing_config)


func _load_typing_data() -> TypingData:
    var typing_data = TypingData.new()
    typing_data.numbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    typing_data.english_bigrams           = _load_language("res://Data/english_bigrams.txt")
    typing_data.english_trigrams          = _load_language("res://Data/english_trigrams.txt")
    typing_data.english_words = {
        TypingData.WordsRarity.VeryCommon : _load_language("res://Data/english_200.txt"),
        TypingData.WordsRarity.Common     : _load_language("res://Data/english_1k.txt"),
        TypingData.WordsRarity.Rare       : _load_language("res://Data/english_25k.txt"),
        TypingData.WordsRarity.VeryRare   : _load_language("res://Data/english_450k.txt"),
    }
    typing_data.test_sizes = {
        TypingData.TestSize.VerySmall  : 1,
        TypingData.TestSize.Small      : 3,
        TypingData.TestSize.Medium     : 6,
        TypingData.TestSize.Large      : 13,
    }
    typing_data.keys = {}
    for key in typing_data.keys_array:
        typing_data.keys[key] = true

    return typing_data


func _load_language(path: String) -> PackedStringArray:
    var words_file = FileAccess.open(path, FileAccess.READ)
    var words_file_content = words_file.get_as_text()
    var line_endings = _get_line_endings(words_file_content)
    var words = words_file_content.split(line_endings)
    words.remove_at(words.size() - 1) # last word has size 0
    return words


func _get_line_endings(file_content: String):
    const unix_endings = "\n"
    const windows_endings = "\r\n"
    var first_few_words = file_content.left(50) # lets hope there wont be 50 char long words...
    if first_few_words.contains(windows_endings):
        return windows_endings
    if first_few_words.contains(unix_endings):
        return unix_endings
    return ""


func _load_typing_config() -> TypingConfig:
    var typing_config = TypingConfig.new()
    typing_config.test_language = TypingData.TestLanguage.English
    typing_config.test_type = TypingData.TestType.Words
    typing_config.words_rarity = TypingData.WordsRarity.VeryCommon
    typing_config.test_size = TypingData.TestSize.Small
    return typing_config


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
