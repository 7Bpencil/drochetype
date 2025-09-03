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
@export var learn_letters_target_color: Color
@export_multiline var learn_letters_item_tooltip: String
@export var test_size_foldable: FoldableContainer
@export var test_size: ItemList


signal generate_new_test()


var typing_data: TypingData
var typing_config: TypingConfig

const no_color = Color(0, 0, 0, 0)

func _ready():
    test_language.item_selected.connect(_on_test_language_selected)
    test_type.item_selected.connect(_on_test_type_selected)
    words_rarity.item_selected.connect(_on_words_rarity_selected)
    include_letter.item_selected.connect(_on_include_letter_selected)
    learn_letters.multi_selected.connect(_on_learn_letters_selected)
    learn_letters.item_clicked.connect(_on_learn_letters_clicked)
    test_size.item_selected.connect(_on_test_size_selected)


func set_data(data: TypingData, config: TypingConfig):
    typing_data = data
    typing_config = config
    _rebuild_ui()


func _on_test_language_selected(index: int):
    typing_config.test_language = index as TypingData.TestLanguage
    typing_config.include_letter = -1
    test_language_foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit()


func _on_test_type_selected(index: int):
    typing_config.test_type = index as TypingData.TestType
    typing_config.include_letter = -1
    test_type_foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit()


func _on_words_rarity_selected(index: int):
    typing_config.words_rarity = index as TypingData.WordsRarity
    words_rarity_foldable.folded = true
    generate_new_test.emit()


func _on_include_letter_selected(index: int):
    typing_config.include_letter = index - 1
    include_letter_foldable.folded = true
    generate_new_test.emit()


func _on_learn_letters_selected(index: int, selected: bool):
    var language_config = typing_config.get_language_config()
    if selected:
        language_config.learn_letters[index] = true
        if language_config.learn_letters_target != -1:
            learn_letters.set_item_custom_bg_color(language_config.learn_letters_target, no_color)
        language_config.learn_letters_target = index
        learn_letters.set_item_custom_bg_color(index, learn_letters_target_color)
    else:
        language_config.learn_letters.erase(index)
        if language_config.learn_letters_target == index:
            language_config.learn_letters_target = -1
            learn_letters.set_item_custom_bg_color(index, no_color)

    generate_new_test.emit()


func _on_learn_letters_clicked(index: int, at_position: Vector2, mouse_button_index: int):
    if mouse_button_index != MOUSE_BUTTON_RIGHT:
        return

    var language_config = typing_config.get_language_config()
    if not language_config.learn_letters.has(index):
        return

    if language_config.learn_letters_target == index:
        language_config.learn_letters_target = -1
        learn_letters.set_item_custom_bg_color(index, no_color)
    else:
        if language_config.learn_letters_target != -1:
            learn_letters.set_item_custom_bg_color(language_config.learn_letters_target, no_color)
        language_config.learn_letters_target = index
        learn_letters.set_item_custom_bg_color(index, learn_letters_target_color)

    generate_new_test.emit()


func _on_test_size_selected(index: int):
    typing_config.test_size = index as TypingData.TestSize
    test_size_foldable.folded = true
    generate_new_test.emit()


func _rebuild_ui():
    match typing_config.test_language:
        TypingData.TestLanguage.Numbers, TypingData.TestLanguage.Symbols:
            test_type_foldable.visible = false
            words_rarity_foldable.visible = false
            include_letter_foldable.visible = false
            learn_letters_foldable.visible = false
        TypingData.TestLanguage.English, TypingData.TestLanguage.Russian:
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
                _rebuild_learn_letters(typing_data.languages[typing_config.test_language].alphabet, typing_config.get_language_config())
            else:
                learn_letters_foldable.visible = false

    test_language.select(typing_config.test_language)
    test_size.select(typing_config.test_size)


func _rebuild_include_letter(alphabet: PackedStringArray):
    include_letter.clear()
    include_letter.add_item("*")
    for letter in alphabet:
        include_letter.add_item(letter)
    include_letter.select(typing_config.include_letter + 1)


func _rebuild_learn_letters(alphabet: PackedStringArray, language_config: TypingConfigNaturalLanguage):
    learn_letters.clear()
    for letter in alphabet:
        var index = learn_letters.add_item(letter)
        learn_letters.set_item_tooltip(index, learn_letters_item_tooltip)
        if language_config.learn_letters.has(index):
            learn_letters.select(index, false)

    if language_config.learn_letters_target != -1:
        learn_letters.set_item_custom_bg_color(language_config.learn_letters_target, learn_letters_target_color)
