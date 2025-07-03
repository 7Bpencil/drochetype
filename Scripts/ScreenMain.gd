class_name ScreenMain extends Node


@export var words_rarity_foldable: FoldableContainer
@export var words_rarity: ItemList


signal start_typing(typing_config: TypingConfig)
signal restart_test_with_new_config(typing_config: TypingConfig)


var typing_config: TypingConfig


func _ready():
    words_rarity.item_selected.connect(_on_words_rarity_selected)


func set_typing_config(config: TypingConfig):
    typing_config = config
    words_rarity.select(typing_config.words_rarity)


func _on_words_rarity_selected(index: int):
    typing_config.words_rarity = index
    words_rarity_foldable.folded = true
    restart_test_with_new_config.emit(typing_config)


func after_init():
    start_typing.emit(typing_config)
