class_name TestGenerator


var typing_data: TypingData
var typing_config: TypingConfig
var available_word_letters: Dictionary
var available_word_tokens: Array
var word_builder: Array


func _init(data: TypingData, config: TypingConfig):
    typing_data = data
    typing_config = config
    available_word_letters = {}
    available_word_tokens = []
    word_builder = []


func generate_next_test() -> void:
    if typing_config.test_language == TypingData.TestLanguage.Numbers:
        return
    if typing_config.test_type == TypingData.TestType.Letters:
        var letters = typing_config.learn_letters[typing_config.test_language]
        var language_data = typing_data.languages[typing_config.test_language]
        _collect_avalilable_word_tokens(letters, language_data.alphabet, language_data.bigrams, language_data.trigrams)


func _collect_avalilable_word_tokens(letter_indices: Dictionary, alphabet: PackedStringArray, bigrams: PackedStringArray, trigrams: PackedStringArray):
    available_word_letters.clear()
    available_word_tokens.clear()

    if letter_indices.size() == 0:
        return "select letters"

    for letter_index in letter_indices:
        var letter = alphabet[letter_index]
        available_word_letters[letter] = true

    # add letters themselves as tokens because rare ones often dont have bigrams/trigrams
    for letter in available_word_letters:
        available_word_tokens.append(letter)

    # get all available bigrams
    for bigram in bigrams:
        if bigram[0] == bigram[1]:
            continue
        var is_available = true
        for letter in bigram:
            if not available_word_letters.has(letter):
                is_available = false
                break
        if is_available:
            available_word_tokens.append(bigram)

    # get all available trigrams
    for trigram in trigrams:
        if trigram[0] == trigram[1] or trigram[1] == trigram[2]:
            continue
        var is_available = true
        for letter in trigram:
            if not available_word_letters.has(letter):
                is_available = false
                break
        if is_available:
            available_word_tokens.append(trigram)


func get_next_word() -> String:
    if typing_config.test_language == TypingData.TestLanguage.Numbers:
        return _get_next_numbers_word()
    return _get_next_natural_language_word(typing_data.languages[typing_config.test_language])


func _get_next_natural_language_word(language_data: NaturalLanguageData) -> String:
    match typing_config.test_type:
        TypingData.TestType.Letters:
            return _generate_word_from_available_word_tokens()
        TypingData.TestType.Bigrams:
            return _get_random_element(language_data.bigrams)
        TypingData.TestType.Trigrams:
            return _get_random_element(language_data.trigrams)
        TypingData.TestType.Words:
            if typing_config.include_letter == 0:
                return _get_random_element(language_data.words[typing_config.words_rarity])
            else:
                var letter = language_data.alphabet[typing_config.include_letter - 1]
                var word_indices = language_data.words_per_letter[typing_config.words_rarity][letter]
                if word_indices.size() == 0:
                    return "no words"
                var word_index = _get_random_element(word_indices)
                var word = language_data.words[typing_config.words_rarity][word_index]
                return word
        _:
            return "error"


# IDEA creating test for learning can not be done word by word
# TODO collecting available tokens can be done after selecting letter, not at generating each word
# for each letter generate its own bigram, otherwise there will be only common bigrams
func _generate_word_from_available_word_tokens() -> String:
    if available_word_tokens.size() == 0:
        return "select letters"

    var word_length = 2

    available_word_tokens.shuffle() # TODO shuffle with priorities
    word_builder.clear()
    word_builder.resize(word_length)
    for i in range(word_length ):
        word_builder[i] = available_word_tokens[i % available_word_tokens.size()]
    word_builder.shuffle()
    return "".join(word_builder)


func _get_next_numbers_word() -> String:
    var word_length = 6
    var numbers = typing_data.languages[TypingData.TestLanguage.Numbers]

    word_builder.clear()
    word_builder.resize(word_length)
    for i in range(word_length):
        var i_looped = i % numbers.size()
        if i_looped == 0:
            numbers.shuffle()
        word_builder[i] = numbers[i_looped]

    return "".join(word_builder)


func _get_random_element(array):
    return array[randi_range(0, array.size() - 1)]
