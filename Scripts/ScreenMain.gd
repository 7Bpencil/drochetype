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


signal generate_new_test()


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


func _on_test_language_selected(index: int):
    typing_config.test_language = index as TypingData.TestLanguage
    typing_config.include_letter = 0
    test_language_foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit()


func _on_test_type_selected(index: int):
    typing_config.test_type = index as TypingData.TestType
    typing_config.include_letter = 0
    test_type_foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit()


func _on_words_rarity_selected(index: int):
    typing_config.words_rarity = index as TypingData.WordsRarity
    words_rarity_foldable.folded = true
    generate_new_test.emit()


func _on_include_letter_selected(index: int):
    typing_config.include_letter = index
    include_letter_foldable.folded = true
    generate_new_test.emit()


func _on_learn_letters_selected(index: int, selected: bool):
    var letter_indices = typing_config.learn_letters[typing_config.test_language]
    if selected:
        letter_indices[index] = LearnLetterData.new()
        learn_letters.set_item_tooltip_enabled(index, true)
        learn_letters.set_item_tooltip(index, _format_learn_letter_tooltip(letter_indices[index]))
    else:
        letter_indices.erase(index)
        learn_letters.set_item_tooltip_enabled(index, false)
    generate_new_test.emit()


func _on_test_size_selected(index: int):
    typing_config.test_size = index as TypingData.TestSize
    test_size_foldable.folded = true
    generate_new_test.emit()


func _rebuild_ui():
    if typing_config.test_language == TypingData.TestLanguage.Numbers:
        test_type_foldable.visible = false
        words_rarity_foldable.visible = false
        include_letter_foldable.visible = false
        learn_letters_foldable.visible = false
    else:
        test_type_foldable.visible = true
        test_type.select(typing_config.test_type)

        if typing_config.test_type == TypingData.TestType.Words:
            words_rarity_foldable.visible = true
            include_letter_foldable.visible = true
            words_rarity.select(typing_config.words_rarity)
            _rebuild_include_letter(typing_data.languages[typing_config.test_language].alphabet)
        else:
            words_rarity_foldable.visible = false
            include_letter_foldable.visible = false

        if typing_config.test_type == TypingData.TestType.Letters:
            learn_letters_foldable.visible = true
            _rebuild_learn_letters(typing_data.languages[typing_config.test_language].alphabet, typing_config.learn_letters[typing_config.test_language])
        else:
            learn_letters_foldable.visible = false

    test_language.select(typing_config.test_language)
    test_size.select(typing_config.test_size)


func _rebuild_include_letter(alphabet: PackedStringArray):
    include_letter.clear()
    include_letter.add_item("*")
    for letter in alphabet:
        include_letter.add_item(letter)
    include_letter.select(typing_config.include_letter)


func _rebuild_learn_letters(alphabet: PackedStringArray, letter_indices: Dictionary):
    learn_letters.clear()
    for letter in alphabet:
        var index = learn_letters.add_item(letter)
        if letter_indices.has(index):
            learn_letters.select(index, false)
            learn_letters.set_item_tooltip_enabled(index, true)
            learn_letters.set_item_tooltip(index, _format_learn_letter_tooltip(letter_indices[index]))
        else:
            learn_letters.set_item_tooltip_enabled(index, false)


# TODO this updates all letters simultaniously, bet there's no need to: just update last one
# or there's need to? hmm...
func update_letter_stats():
    if typing_config.test_language == TypingData.TestLanguage.Numbers:
        return
    if typing_config.test_type != TypingData.TestType.Letters:
        return
    var letter_indices = typing_config.learn_letters[typing_config.test_language]
    for index in letter_indices:
        learn_letters.set_item_tooltip(index, _format_learn_letter_tooltip(letter_indices[index]))


func _format_learn_letter_tooltip(letter_data: LearnLetterData) -> String:
    return "hits: %s\nmistakes: %s" % [letter_data.hits_count, letter_data.mistakes_count]
