class_name TypingConfig


var test_language: TypingData.TestLanguage
var test_type: TypingData.TestType
var words_rarity: TypingData.WordsRarity
var include_letter: int
var learn_letters: Dictionary
var test_size: TypingData.TestSize

const _save_file_path: String = "res://save.json"


static func load() -> TypingConfig:
    if not FileAccess.file_exists(_save_file_path):
        return _create_default_config()

    var save_file = FileAccess.open(_save_file_path, FileAccess.READ)
    var save_json = save_file.get_line()
    var json = JSON.new()
    var parse_result = json.parse(save_json)
    
    if not parse_result == OK:
        print("JSON Parse Error: %s in %s at line %s" % [json.get_error_message(), save_json, json.get_error_line()])
        return _create_default_config()

    var save = json.data
    var typing_config = TypingConfig.new()
    typing_config.test_language  = save["test_language"] as TypingData.TestLanguage
    typing_config.test_type      = save["test_type"] as TypingData.TestType
    typing_config.words_rarity   = save["words_rarity"] as TypingData.WordsRarity
    typing_config.include_letter = save["include_letter"]
    typing_config.learn_letters  = {}
    typing_config.test_size      = save["test_size"] as TypingData.TestSize

    return typing_config


static func _create_default_config() -> TypingConfig:
    var typing_config = TypingConfig.new()
    typing_config.test_language  = TypingData.TestLanguage.English
    typing_config.test_type      = TypingData.TestType.Words
    typing_config.words_rarity   = TypingData.WordsRarity.VeryCommon
    typing_config.include_letter = 0
    typing_config.learn_letters  = {}
    typing_config.test_size      = TypingData.TestSize.Small

    return typing_config
    

# TODO we call it at every change in config, so it does block main thread,
# would be good to make it async, or at least switch to binary to make if faster
func save():
    var save_file = FileAccess.open(_save_file_path, FileAccess.WRITE)
    var save = {
        "test_language"  : test_language,
        "test_type"      : test_type,
        "words_rarity"   : words_rarity,
        "include_letter" : include_letter,
        "test_size"      : test_size,
    }
    var save_json = JSON.stringify(save, "", false, false)
    save_file.store_line(save_json)


func on_test_completion():
    pass
