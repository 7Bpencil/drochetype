class_name ScreenMain extends Node


@export var test_language_foldable: FoldableContainer
@export var test_language: ItemList
@export var test_type_foldable: FoldableContainer
@export var test_type: ItemList
@export var words_rarity_foldable: FoldableContainer
@export var words_rarity: ItemList
@export var include_letter_foldable: FoldableContainer
@export var include_letter: ItemList
@export var learn_letters_foldable: FoldableContainer
@export var learn_letters: ItemList
@export var test_size_foldable: FoldableContainer
@export var test_size: ItemList


signal generate_new_test(typing_config: TypingConfig)


var typing_data: TypingData
var typing_config: TypingConfig


func _ready():
    test_language.item_selected.connect(_on_test_language_selected)
    test_type.item_selected.connect(_on_test_type_selected)
    words_rarity.item_selected.connect(_on_words_rarity_selected)
    include_letter.item_selected.connect(_on_include_letter_selected)
    learn_letters.multi_selected.connect(_on_learn_letters_selected)
    test_size.item_selected.connect(_on_test_size_selected)


func set_data(data: TypingData, config: TypingConfig):
    typing_data = data
    typing_config = config

    _rebuild_ui()
    test_language.select(typing_config.test_language)
    test_type.select(typing_config.test_type)
    words_rarity.select(typing_config.words_rarity)
    include_letter.select(typing_config.include_letter)
    test_size.select(typing_config.test_size)


func _on_test_language_selected(index: int):
    typing_config.test_language = index as TypingData.TestLanguage
    typing_config.include_letter = 0
    typing_config.learn_letters.clear()
    test_language_foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit(typing_config)


func _on_test_type_selected(index: int):
    typing_config.test_type = index as TypingData.TestType
    typing_config.include_letter = 0
    typing_config.learn_letters.clear()
    test_type_foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit(typing_config)


func _on_words_rarity_selected(index: int):
    typing_config.words_rarity = index as TypingData.WordsRarity
    words_rarity_foldable.folded = true
    generate_new_test.emit(typing_config)


func _on_include_letter_selected(index: int):
    typing_config.include_letter = index
    include_letter_foldable.folded = true
    generate_new_test.emit(typing_config)


func _on_learn_letters_selected(index: int, selected: bool):
    if selected:
        typing_config.learn_letters[index] = LearnLetterData.new()
    else:
        typing_config.learn_letters.erase(index)
    generate_new_test.emit(typing_config)


func _on_test_size_selected(index: int):
    typing_config.test_size = index as TypingData.TestSize
    test_size_foldable.folded = true
    generate_new_test.emit(typing_config)


func _rebuild_ui():
    if typing_config.test_language == TypingData.TestLanguage.Numbers:
        test_type_foldable.visible = false
        words_rarity_foldable.visible = false
        include_letter_foldable.visible = false
        learn_letters_foldable.visible = false
    else:
        test_type_foldable.visible = true
        words_rarity_foldable.visible = typing_config.test_type == TypingData.TestType.Words

        if typing_config.test_type == TypingData.TestType.Words:
            include_letter_foldable.visible = true
            _rebuild_include_letter()
        else:
            include_letter_foldable.visible = false

        if typing_config.test_type == TypingData.TestType.Letters:
            learn_letters_foldable.visible = true
            _rebuild_learn_letters()
        else:
            learn_letters_foldable.visible = false


func _rebuild_include_letter():
    if typing_config.test_language == TypingData.TestLanguage.English:
        _set_language_alphabet_include_letter(typing_data.english.alphabet)
    if typing_config.test_language == TypingData.TestLanguage.Russian:
        _set_language_alphabet_include_letter(typing_data.russian.alphabet)


func _set_language_alphabet_include_letter(alphabet: PackedStringArray):
    include_letter.clear()
    include_letter.add_item("*")
    for letter in alphabet:
        include_letter.add_item(letter)
    include_letter.select(typing_config.include_letter)


func _rebuild_learn_letters():
    if typing_config.test_language == TypingData.TestLanguage.English:
        _set_language_alphabet_learn_letters(typing_data.english.alphabet)
    if typing_config.test_language == TypingData.TestLanguage.Russian:
        _set_language_alphabet_learn_letters(typing_data.russian.alphabet)


func _set_language_alphabet_learn_letters(alphabet: PackedStringArray):
    learn_letters.clear()
    for letter in alphabet:
        learn_letters.add_item(letter)
