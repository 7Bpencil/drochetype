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

    var english = NaturalLanguageData.new()
    english.alphabet                      = _load_lines("res://Data/english_alphabet.txt")
    english.alphabet_dict                 = _build_alphabet_dict(english.alphabet)
    english.bigrams                       = _load_lines("res://Data/english_bigrams.txt")
    english.trigrams                      = _load_lines("res://Data/english_trigrams.txt")
    english.words = {
        TypingData.WordsRarity.VeryCommon : _load_monkeytype_words("res://Data/english.json"),
        TypingData.WordsRarity.Common     : _load_monkeytype_words("res://Data/english_1k.json"),
        TypingData.WordsRarity.Rare       : _load_monkeytype_words("res://Data/english_25k.json"),
        TypingData.WordsRarity.VeryRare   : _load_monkeytype_words("res://Data/english_450k.json"),
    }
    english.words_per_letter              = _filter_words_per_letter(english.words, english.alphabet)

    var russian = NaturalLanguageData.new()
    russian.alphabet                      = _load_lines("res://Data/russian_alphabet.txt")
    russian.alphabet_dict                 = _build_alphabet_dict(russian.alphabet)
    russian.bigrams                       = _load_lines("res://Data/russian_bigrams.txt")
    russian.trigrams                      = _load_lines("res://Data/russian_trigrams.txt")
    russian.words = {
        TypingData.WordsRarity.VeryCommon : _load_monkeytype_words("res://Data/russian.json"),
        TypingData.WordsRarity.Common     : _load_monkeytype_words("res://Data/russian_1k.json"),
        TypingData.WordsRarity.Rare       : _load_monkeytype_words("res://Data/russian_25k.json"),
        TypingData.WordsRarity.VeryRare   : _load_monkeytype_words("res://Data/russian_375k.json"),
    }
    russian.words_per_letter              = _filter_words_per_letter(russian.words, russian.alphabet)

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


static func _load_lines(path: String) -> PackedStringArray:
    var file = FileAccess.open(path, FileAccess.READ)
    var file_content = file.get_as_text(true)
    var lines = file_content.split("\n")
    lines.remove_at(lines.size() - 1) # last word has size 0
    return lines


static func _load_monkeytype_words(filepath: String) -> PackedStringArray:
    var file = FileAccess.open(filepath, FileAccess.READ)
    var file_content = file.get_as_text()
    var json = JSON.new()
    var error = json.parse(file_content)
    if error != OK:
        printerr("JSON Parse Error: ", json.get_error_message(), " in ", filepath, " at line ", json.get_error_line())
        return ["error"]

    if not json.data.has("words"):
        printerr("JSON: ", filepath, " does not contains words (expected dict with key 'words' and array of strings as value)")
        return ["error"]

    return json.data["words"]


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

            # do not include word multiple times because it has repeating characters
            if letter_cache.has(letter):
                continue

            result[letter].append(word_index)
            letter_cache[letter] = true

    return result
