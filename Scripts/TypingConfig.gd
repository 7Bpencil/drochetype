class_name TypingConfig extends Resource


@export var test_language: TypingData.TestLanguage
@export var test_type: TypingData.TestType
@export var words_rarity: TypingData.WordsRarity
@export var include_letter: int
@export var learn_letters: Dictionary
@export var test_size: TypingData.TestSize

# TODO move it to user://save.bin
const _save_file_path: String = "res://save.bin"


static func load() -> TypingConfig:
    if not FileAccess.file_exists(_save_file_path):
        return _create_default_config()

    var save_file = FileAccess.open(_save_file_path, FileAccess.READ)
    return save_file.get_var(true)


static func _create_default_config() -> TypingConfig:
    var typing_config = TypingConfig.new()
    typing_config.test_language  = TypingData.TestLanguage.English
    typing_config.test_type      = TypingData.TestType.Words
    typing_config.words_rarity   = TypingData.WordsRarity.VeryCommon
    typing_config.include_letter = 0
    typing_config.learn_letters  = {
        TypingData.TestLanguage.English : {},
        TypingData.TestLanguage.Russian : {},
    }
    typing_config.test_size      = TypingData.TestSize.Small

    return typing_config


# TODO we call it at every change in config, so it does block main thread, would be good to make it async
func save():
    var save_file = FileAccess.open(_save_file_path, FileAccess.WRITE)
    save_file.store_var(self, true)
