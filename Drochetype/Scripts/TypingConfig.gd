class_name TypingConfig extends Resource


@export var test_language: TypingData.TestLanguage
@export var test_type: TypingData.TestType
@export var words_rarity: TypingData.WordsRarity
@export var include_letter: int
@export var language_configs: Dictionary
@export var test_size: TypingData.TestSize

const _save_file_path: String = "user://save.bin"


static func load() -> TypingConfig:
    if not FileAccess.file_exists(_save_file_path):
        return _create_default_config()

    var save_file = FileAccess.open_compressed(_save_file_path, FileAccess.READ, FileAccess.CompressionMode.COMPRESSION_ZSTD)
    return save_file.get_var(true)


static func _create_default_config() -> TypingConfig:
    var typing_config = TypingConfig.new()
    typing_config.test_language    = TypingData.TestLanguage.Natural
    typing_config.test_type        = TypingData.TestType.Words
    typing_config.words_rarity     = TypingData.WordsRarity.VeryCommon
    typing_config.include_letter   = -1
    typing_config.language_configs = {}
    typing_config.test_size        = TypingData.TestSize.Small

    return typing_config


func get_language_config() -> TypingConfigNaturalLanguage:
    if language_configs.has(test_language):
        return language_configs[test_language]

    var new_config = TypingConfigNaturalLanguage.new()
    language_configs[test_language] = new_config
    return new_config


func save():
    var save_file = FileAccess.open_compressed(_save_file_path, FileAccess.WRITE, FileAccess.CompressionMode.COMPRESSION_ZSTD)
    save_file.store_var(self, true)
