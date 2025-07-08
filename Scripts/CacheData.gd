@tool
extends EditorScript


func _run():
    var typing_data = TypingData.new()

    typing_data.numbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

    typing_data.english = NaturalLanguageData.new()
    typing_data.english.alphabet          = _load_language("res://Data/english_alphabet.txt")
    typing_data.english.bigrams           = _load_language("res://Data/english_bigrams.txt")
    typing_data.english.trigrams          = _load_language("res://Data/english_trigrams.txt")
    typing_data.english.words = {
        TypingData.WordsRarity.VeryCommon : _load_language("res://Data/english_200.txt"),
        TypingData.WordsRarity.Common     : _load_language("res://Data/english_1k.txt"),
        TypingData.WordsRarity.Rare       : _load_language("res://Data/english_25k.txt"),
        TypingData.WordsRarity.VeryRare   : _load_language("res://Data/english_450k.txt"),
    }
    typing_data.english.words_per_letter  = _filter_words(typing_data.english.words, typing_data.english.alphabet)

    typing_data.russian = NaturalLanguageData.new()
    typing_data.russian.alphabet          = _load_language("res://Data/russian_alphabet.txt")
    typing_data.russian.bigrams           = _load_language("res://Data/russian_bigrams.txt")
    typing_data.russian.trigrams          = _load_language("res://Data/russian_trigrams.txt")
    typing_data.russian.words = {
        TypingData.WordsRarity.VeryCommon : _load_language("res://Data/russian_200.txt"),
        TypingData.WordsRarity.Common     : _load_language("res://Data/russian_1k.txt"),
        TypingData.WordsRarity.Rare       : _load_language("res://Data/russian_25k.txt"),
        TypingData.WordsRarity.VeryRare   : _load_language("res://Data/russian_375k.txt"),
    }
    typing_data.russian.words_per_letter  = _filter_words(typing_data.russian.words, typing_data.russian.alphabet)

    typing_data.test_sizes = {
        TypingData.TestSize.VerySmall  : 1,
        TypingData.TestSize.Small      : 3,
        TypingData.TestSize.Medium     : 6,
        TypingData.TestSize.Large      : 13,
    }

    typing_data.keycodes = {}
    for keycode in typing_data.keycodes_array:
        typing_data.keycodes[keycode] = true

    var file = FileAccess.open_compressed(TypingData.cache_path, FileAccess.WRITE, FileAccess.CompressionMode.COMPRESSION_ZSTD)
    file.store_var(typing_data, true)


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


func _filter_words(words: Dictionary, alphabet: PackedStringArray):
    var result = {}
    for word_rarity in words:
        var all_words = words[word_rarity]
        result[word_rarity] = _filter_words_per_letter(all_words, alphabet)

    return result


func _filter_words_per_letter(all_words: PackedStringArray, alphabet: PackedStringArray):
    var result: Dictionary = {}
    for letter in alphabet:
        result[letter] = []
    var letter_cache = {}
    for word_index in range(all_words.size()):
        var word = all_words[word_index]
        letter_cache.clear()
        for letter in word:
            if not result.has(letter): # for words with non alphabet characters inside
                continue
            if letter_cache.has(letter):
                continue
            result[letter].append(word_index)
            letter_cache[letter] = true

    return result
