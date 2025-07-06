class_name ScreenMain extends Node

@export var test_language_foldable: FoldableContainer
@export var test_language: ItemList
@export var test_type_foldable: FoldableContainer
@export var test_type: ItemList
@export var words_rarity_foldable: FoldableContainer
@export var words_rarity: ItemList
@export var test_size_foldable: FoldableContainer
@export var test_size: ItemList


signal generate_new_test(typing_config: TypingConfig)


var typing_config: TypingConfig


func _ready():
    test_language.item_selected.connect(_on_test_language_selected)
    test_type.item_selected.connect(_on_test_type_selected)
    words_rarity.item_selected.connect(_on_words_rarity_selected)
    test_size.item_selected.connect(_on_test_size_selected)


func set_typing_config(config: TypingConfig):
    typing_config = config
    test_language.select(typing_config.test_language)
    test_type.select(typing_config.test_type)
    words_rarity.select(typing_config.words_rarity)
    test_size.select(typing_config.test_size)
    _rebuild_ui()


func _on_test_language_selected(index: int):
    typing_config.test_language = index
    test_language_foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit(typing_config)


func _on_test_type_selected(index: int):
    typing_config.test_type = index
    test_type_foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit(typing_config)


func _on_words_rarity_selected(index: int):
    typing_config.words_rarity = index
    words_rarity_foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit(typing_config)


func _on_test_size_selected(index: int):
    typing_config.test_size = index
    test_size_foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit(typing_config)


func _rebuild_ui():
    if typing_config.test_language == TypingData.TestLanguage.Numbers:
        test_type_foldable.visible = false
        words_rarity_foldable.visible = false
    else:
        test_type_foldable.visible = true
        words_rarity_foldable.visible = typing_config.test_type == TypingData.TestType.Words
