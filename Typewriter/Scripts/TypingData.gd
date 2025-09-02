class_name TypingData extends Resource

enum TestLanguage {
    Numbers,
    Symbols,
    English,
    Russian,
}

enum TestType {
    Letters,
    Bigrams,
    Trigrams,
    Words,
}

enum WordsRarity {
    VeryCommon,
    Common,
    Rare,
    VeryRare,
}

enum TestSize {
    VerySmall,
    Small,
    Medium,
    Large,
}

@export var languages: Dictionary
@export var test_sizes: Dictionary
@export var keycodes: Dictionary

const _cache_file_path: String = "res://data.bin"

const _keycodes_array: Array[Key] = [
    # alphabet
    KEY_A,
    KEY_B,
    KEY_C,
    KEY_D,
    KEY_E,
    KEY_F,
    KEY_G,
    KEY_H,
    KEY_I,
    KEY_J,
    KEY_K,
    KEY_L,
    KEY_M,
    KEY_N,
    KEY_O,
    KEY_P,
    KEY_Q,
    KEY_R,
    KEY_S,
    KEY_T,
    KEY_U,
    KEY_V,
    KEY_W,
    KEY_X,
    KEY_Y,
    KEY_Z,
    # numbers
    KEY_0,
    KEY_1,
    KEY_2,
    KEY_3,
    KEY_4,
    KEY_5,
    KEY_6,
    KEY_7,
    KEY_8,
    KEY_9,
    # symbols
    KEY_MINUS,
    KEY_EQUAL,
    KEY_BRACKETLEFT,
    KEY_BRACKETRIGHT,
    KEY_BACKSLASH,
    KEY_SEMICOLON,
    KEY_APOSTROPHE,
    KEY_SLASH,
    KEY_COMMA,
    KEY_PERIOD,
    KEY_QUOTELEFT,
    # special
    KEY_SPACE,
]


static func load() -> TypingData:
    var file = FileAccess.open_compressed(_cache_file_path, FileAccess.READ, FileAccess.CompressionMode.COMPRESSION_ZSTD)
    return file.get_var(true)


static func cache() -> void:
    var typing_data = TypingData.new()

    var numbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    var symbols = ["+", "-", "*", "/", "\\", ",", ".", "=", "!", "?", "_", "%", "@", "$", "|", "&", "#", ":", ";", "^", "(", ")", "{", "}", "[", "]", "<", ">", "\"", "'", "`", "~"]

    var english = TypingDataNaturalLanguage.new()
    var english_config = TypingDataNaturalLanguageConfig.new()
    english_config.alphabet          = "res://Typewriter/Data/english_alphabet.txt"
    english_config.bigrams           = "res://Typewriter/Data/english_bigrams.txt"
    english_config.trigrams          = "res://Typewriter/Data/english_trigrams.txt"
    english_config.words_very_common = "res://Typewriter/Data/english.json"
    english_config.words_common      = "res://Typewriter/Data/english_1k.json"
    english_config.words_rare        = "res://Typewriter/Data/english_25k.json"
    english_config.words_very_rare   = "res://Typewriter/Data/english_450k.json"
    var english_thread = Thread.new()
    english_thread.start(_load_natural_language.bind(english, english_config))

    var russian = TypingDataNaturalLanguage.new()
    var russian_config = TypingDataNaturalLanguageConfig.new()
    russian_config.alphabet          = "res://Typewriter/Data/russian_alphabet.txt"
    russian_config.bigrams           = "res://Typewriter/Data/russian_bigrams.txt"
    russian_config.trigrams          = "res://Typewriter/Data/russian_trigrams.txt"
    russian_config.words_very_common = "res://Typewriter/Data/russian.json"
    russian_config.words_common      = "res://Typewriter/Data/russian_1k.json"
    russian_config.words_rare        = "res://Typewriter/Data/russian_25k.json"
    russian_config.words_very_rare   = "res://Typewriter/Data/russian_375k.json"
    var russian_thread = Thread.new()
    russian_thread.start(_load_natural_language.bind(russian, russian_config))

    english_thread.wait_to_finish()
    russian_thread.wait_to_finish()

    typing_data.languages = {
        TypingData.TestLanguage.Numbers : numbers,
        TypingData.TestLanguage.Symbols : symbols,
        TypingData.TestLanguage.English : english,
        TypingData.TestLanguage.Russian : russian,
    }

    typing_data.test_sizes = {
        TypingData.TestSize.VerySmall : 1,
        TypingData.TestSize.Small     : 3,
        TypingData.TestSize.Medium    : 6,
        TypingData.TestSize.Large     : 12,
    }

    typing_data.keycodes = {}
    for keycode in _keycodes_array:
        typing_data.keycodes[keycode] = true

    var file = FileAccess.open_compressed(_cache_file_path, FileAccess.WRITE, FileAccess.CompressionMode.COMPRESSION_ZSTD)
    file.store_var(typing_data, true)
    print("Cached data successfully")


static func _load_natural_language(result: TypingDataNaturalLanguage, config: TypingDataNaturalLanguageConfig):
    result.alphabet                       = _load_lines(config.alphabet)
    result.alphabet_dict                  = _build_alphabet_dict(result.alphabet)
    result.bigrams                        = _load_lines(config.bigrams)
    result.trigrams                       = _load_lines(config.trigrams)
    result.words = {
        TypingData.WordsRarity.VeryCommon : _load_monkeytype_words(config.words_very_common),
        TypingData.WordsRarity.Common     : _load_monkeytype_words(config.words_common),
        TypingData.WordsRarity.Rare       : _load_monkeytype_words(config.words_rare),
        TypingData.WordsRarity.VeryRare   : _load_monkeytype_words(config.words_very_rare),
    }
    result.words_per_letter               = _filter_words_per_letter(result.words, result.alphabet)


static func _load_lines(path: String) -> PackedStringArray:
    var file = FileAccess.open(path, FileAccess.READ)
    var file_content = file.get_as_text(true)
    var lines = file_content.split("\n")
    var last_line_index = lines.size() - 1
    if lines[last_line_index].length() == 0:
        lines.remove_at(last_line_index)
    return lines


static func _load_monkeytype_words(filepath: String) -> PackedStringArray:
    var file = FileAccess.open(filepath, FileAccess.READ)
    var file_content = file.get_as_text()
    # some words have capital letters in them, I don't like it.
    # so, just lower an entire file, its much faster than lowering each word separately
    file_content = file_content.to_lower()

    var json = JSON.new()
    var error = json.parse(file_content)
    if error != OK:
        printerr("JSON Parse Error: ", json.get_error_message(), " in ", filepath, " at line ", json.get_error_line())
        return ["error"]

    if not json.data.has("words"):
        printerr("JSON: ", filepath, " does not contains words (expected dict with key 'words' and array of strings as value)")
        return ["error"]

    var words = json.data["words"]
    var i: int = 0
    while i < words.size():
        var word = words[i]
        # not interested in one letter words
        if word.length() < 2:
            var last_element_index = words.size() - 1
            words[i] = words[last_element_index]
            words.remove_at(last_element_index)
        else:
            i += 1

    return words


static func _build_alphabet_dict(alphabet: PackedStringArray) -> Dictionary:
    var result = {}
    for i in range(alphabet.size()):
        var letter = alphabet[i]
        result[letter] = i

    return result


static func _filter_words_per_letter(words: Dictionary, alphabet: PackedStringArray) -> Dictionary:
    var result = {}
    for word_rarity in words:
        var all_words = words[word_rarity]
        result[word_rarity] = _filter_words_per_letter_inner(all_words, alphabet)

    return result


static func _filter_words_per_letter_inner(all_words: PackedStringArray, alphabet: PackedStringArray) -> Dictionary:
    var result: Dictionary = {}
    for letter in alphabet:
        result[letter] = []
    var letter_cache = {}
    for word_index in range(all_words.size()):
        var word = all_words[word_index]
        letter_cache.clear()
        for letter in word:
            # for words with non alphabet characters inside
            if not result.has(letter):
                continue

            # prevent including word multiple times if it has repeating characters
            if letter_cache.has(letter):
                continue

            result[letter].append(word_index)
            letter_cache[letter] = true

    return result
