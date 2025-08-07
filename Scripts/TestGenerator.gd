class_name TestGenerator


var typing_data: TypingData
var typing_config: TypingConfig
var available_word_tokens_per_letter: Dictionary
var available_word_tokens: Array[String]
var available_word_tokens_copy: Array[String]
var target_letter: String
var word_builder: Array[String]


func _init(data: TypingData, config: TypingConfig):
    typing_data = data
    typing_config = config
    available_word_tokens_per_letter = {}
    available_word_tokens = []
    available_word_tokens_copy = []
    word_builder = []


func generate_next_test() -> void:
    match typing_config.test_language:
        TypingData.TestLanguage.English, TypingData.TestLanguage.Russian when typing_config.test_type == TypingData.TestType.Letters:
            var language_config = typing_config.language_configs[typing_config.test_language]
            var language_data = typing_data.languages[typing_config.test_language]
            _collect_avalilable_word_tokens(language_config, language_data.alphabet, language_data.bigrams, language_data.trigrams)


func _collect_avalilable_word_tokens(language_config: TypingConfigNaturalLanguage, alphabet: PackedStringArray, bigrams: PackedStringArray, trigrams: PackedStringArray):
    available_word_tokens_per_letter.clear()
    available_word_tokens.clear()
    available_word_tokens_copy.clear()

    var letter_indices = language_config.learn_letters
    if letter_indices.size() == 0:
        return "select letters"

    var target_letter_index = language_config.learn_letters_target
    if target_letter_index == -1:
        target_letter = ""
    else:
        target_letter = alphabet[target_letter_index]

    for letter_index in letter_indices:
        var letter = alphabet[letter_index]
        available_word_tokens_per_letter[letter] = LetterTokens.new()

    # add letters themselves as tokens because rare ones often dont have bigrams/trigrams
    for letter in available_word_tokens_per_letter:
        available_word_tokens_per_letter[letter].push_unique_token(letter)

    # get all available bigrams
    for bigram in bigrams:
        if bigram[0] == bigram[1]:
            continue
        var is_available = true
        for letter in bigram:
            if not available_word_tokens_per_letter.has(letter):
                is_available = false
                break
        if is_available:
            available_word_tokens_per_letter[bigram[0]].push_unique_token(bigram)
            available_word_tokens_per_letter[bigram[1]].push_shared_token(bigram)

    # get all available trigrams
    for trigram in trigrams:
        if trigram[0] == trigram[1] or trigram[1] == trigram[2]:
            continue
        var is_available = true
        for letter in trigram:
            if not available_word_tokens_per_letter.has(letter):
                is_available = false
                break
        if is_available:
            available_word_tokens_per_letter[trigram[0]].push_unique_token(trigram)
            available_word_tokens_per_letter[trigram[1]].push_shared_token(trigram)
            available_word_tokens_per_letter[trigram[2]].push_shared_token(trigram)

    # our goal is to have all letters appear in equal amounts throughout test
    var max_tokens_count = 0
    for letter in available_word_tokens_per_letter:
        var letter_tokens = available_word_tokens_per_letter[letter]
        if letter_tokens.total_tokens_count > max_tokens_count:
            max_tokens_count = letter_tokens.total_tokens_count

    # sometimes theres no bigrams or trigrams, so just use letters themselves
    if max_tokens_count == 0:
        max_tokens_count = 1

    # make rare letters more common by adding letter themselves as tokens
    for letter in available_word_tokens_per_letter:
        var letter_tokens = available_word_tokens_per_letter[letter]
        letter_tokens.fill_tokens(letter, max_tokens_count, available_word_tokens)


class LetterTokens:
    var total_tokens_count: int = 0
    var unique_tokens: Array[String] = []

    func push_unique_token(token: String):
        total_tokens_count += 1
        unique_tokens.append(token)

    func push_shared_token(token: String):
        total_tokens_count += 1

    func fill_tokens(letter: String, target_count: int, target_array: Array[String]):
        target_array.append_array(unique_tokens)
        var diff = target_count - total_tokens_count
        if diff > 0:
            for i in range(diff):
                target_array.append(letter)


func get_next_word() -> String:
    match typing_config.test_language:
        TypingData.TestLanguage.Numbers:
            return _construct_random_word(6, typing_data.languages[TypingData.TestLanguage.Numbers])
        TypingData.TestLanguage.Symbols:
            return _construct_random_word(4, typing_data.languages[TypingData.TestLanguage.Symbols])
        TypingData.TestLanguage.English, TypingData.TestLanguage.Russian:
            return _get_next_natural_language_word(typing_data.languages[typing_config.test_language])
        _:
            return "error"


func _get_next_natural_language_word(language_data: NaturalLanguageData) -> String:
    match typing_config.test_type:
        TypingData.TestType.Letters:
            return _generate_word_from_available_word_tokens()
        TypingData.TestType.Bigrams:
            return _get_random_element(language_data.bigrams)
        TypingData.TestType.Trigrams:
            return _get_random_element(language_data.trigrams)
        TypingData.TestType.Words:
            if typing_config.include_letter == -1:
                return _get_random_element(language_data.words[typing_config.words_rarity])
            else:
                var letter = language_data.alphabet[typing_config.include_letter]
                var word_indices = language_data.words_per_letter[typing_config.words_rarity][letter]
                if word_indices.size() == 0:
                    return "no words"
                var word_index = _get_random_element(word_indices)
                var word = language_data.words[typing_config.words_rarity][word_index]
                return word
        _:
            return "error"


func _generate_word_from_available_word_tokens() -> String:
    if available_word_tokens.size() == 0:
        return "select letters"

    var word_length = 3

    word_builder.clear()
    for i in range(word_length):
        if available_word_tokens_copy.size() == 0:
            available_word_tokens_copy.append_array(available_word_tokens)
            available_word_tokens_copy.shuffle()

        word_builder.append(available_word_tokens_copy.pop_back())

    # if target letter has not appeared in the word naturaly, then add it after-the-fact
    if target_letter != "":
        var has_target_letter = false
        for token in word_builder:
            if token.contains(target_letter):
                has_target_letter = true
                break
        if not has_target_letter:
            var new_token = available_word_tokens_per_letter[target_letter].unique_tokens.pick_random()
            word_builder.append(new_token)

    word_builder.shuffle()
    return "".join(word_builder)


func _construct_random_word(word_length: int, letters: Array) -> String:
    word_builder.clear()
    word_builder.resize(word_length)
    for i in range(word_length):
        var i_looped = i % letters.size()
        if i_looped == 0:
            letters.shuffle()
        word_builder[i] = letters[i_looped]

    return "".join(word_builder)


func _get_random_element(array):
    return array[randi_range(0, array.size() - 1)]
