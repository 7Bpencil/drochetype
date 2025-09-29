class_name ScreenMain extends Node


@export var test_language: FoldableItemList
@export var test_type: FoldableItemList
@export var words_rarity: FoldableItemList
@export var include_letter: FoldableItemList
@export var learn_letters: FoldableItemList
@export var learn_letters_target_color: Color
@export_multiline var learn_letters_item_tooltip: String
@export var test_size: FoldableItemList


signal generate_new_test()


var typing_data: TypingData
var typing_config: TypingConfig
var groups: Array[FoldableItemList]
var focused_group_index: int
var is_focused_group_folded: bool

const no_color = Color(0, 0, 0, 0)

func _ready():
    test_language .list.item_selected.connect(_on_test_language_selected)
    test_type     .list.item_selected.connect(_on_test_type_selected)
    words_rarity  .list.item_selected.connect(_on_words_rarity_selected)
    include_letter.list.item_selected.connect(_on_include_letter_selected)
    learn_letters .list.multi_selected.connect(_on_learn_letters_selected)
    learn_letters .list.item_clicked.connect(_on_learn_letters_clicked)
    test_size     .list.item_selected.connect(_on_test_size_selected)

    test_language .foldable.folding_changed.connect(func(is_folded: bool): _on_folded(test_language, is_folded))
    test_type     .foldable.folding_changed.connect(func(is_folded: bool): _on_folded(test_type, is_folded))
    words_rarity  .foldable.folding_changed.connect(func(is_folded: bool): _on_folded(words_rarity, is_folded))
    include_letter.foldable.folding_changed.connect(func(is_folded: bool): _on_folded(include_letter, is_folded))
    learn_letters .foldable.folding_changed.connect(func(is_folded: bool): _on_folded(learn_letters, is_folded))
    test_size     .foldable.folding_changed.connect(func(is_folded: bool): _on_folded(test_size, is_folded))


func set_data(data: TypingData, config: TypingConfig):
    typing_data = data
    typing_config = config
    for i in range(TypingData.TestLanguage.Natural, typing_data.languages.size()):
        var natural_language = typing_data.languages[i]
        test_language.list.add_item(natural_language.name)
    _rebuild_ui()


func _on_test_language_selected(index: int):
    typing_config.test_language = index as TypingData.TestLanguage
    typing_config.include_letter = -1
    test_language.foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit()


func _on_test_type_selected(index: int):
    typing_config.test_type = index as TypingData.TestType
    typing_config.include_letter = -1
    test_type.foldable.folded = true
    _rebuild_ui()
    generate_new_test.emit()


func _on_words_rarity_selected(index: int):
    typing_config.words_rarity = index as TypingData.WordsRarity
    words_rarity.foldable.folded = true
    generate_new_test.emit()


func _on_include_letter_selected(index: int):
    typing_config.include_letter = index - 1
    include_letter.foldable.folded = true
    generate_new_test.emit()


func _on_learn_letters_selected(index: int, selected: bool):
    var language_config = typing_config.get_language_config()
    if selected:
        language_config.learn_letters[index] = true
        if language_config.learn_letters_target != -1:
            learn_letters.list.set_item_custom_bg_color(language_config.learn_letters_target, no_color)
        language_config.learn_letters_target = index
        learn_letters.list.set_item_custom_bg_color(index, learn_letters_target_color)
    else:
        language_config.learn_letters.erase(index)
        if language_config.learn_letters_target == index:
            language_config.learn_letters_target = -1
            learn_letters.list.set_item_custom_bg_color(index, no_color)

    generate_new_test.emit()


func _on_learn_letters_clicked(index: int, at_position: Vector2, mouse_button_index: int):
    if mouse_button_index != MOUSE_BUTTON_RIGHT:
        return

    var language_config = typing_config.get_language_config()
    if not language_config.learn_letters.has(index):
        return

    if language_config.learn_letters_target == index:
        language_config.learn_letters_target = -1
        learn_letters.list.set_item_custom_bg_color(index, no_color)
    else:
        if language_config.learn_letters_target != -1:
            learn_letters.list.set_item_custom_bg_color(language_config.learn_letters_target, no_color)
        language_config.learn_letters_target = index
        learn_letters.list.set_item_custom_bg_color(index, learn_letters_target_color)

    generate_new_test.emit()


func _on_test_size_selected(index: int):
    typing_config.test_size = index as TypingData.TestSize
    test_size.foldable.folded = true
    generate_new_test.emit()


func _rebuild_ui():
    groups.clear()

    groups.append(test_language)
    test_language.list.select(typing_config.test_language)

    if typing_config.test_language == TypingData.TestLanguage.Numbers or typing_config.test_language == TypingData.TestLanguage.Symbols:
        test_type.foldable.visible = false
        words_rarity.foldable.visible = false
        include_letter.foldable.visible = false
        learn_letters.foldable.visible = false

    if typing_config.test_language >= TypingData.TestLanguage.Natural:
        groups.append(test_type)
        test_type.foldable.visible = true
        test_type.list.select(typing_config.test_type)

        if typing_config.test_type == TypingData.TestType.Words:
            groups.append(words_rarity)
            words_rarity.foldable.visible = true
            words_rarity.list.select(typing_config.words_rarity)
            groups.append(include_letter)
            include_letter.foldable.visible = true
            _rebuild_include_letter(typing_data.languages[typing_config.test_language].alphabet)
        else:
            words_rarity.foldable.visible = false
            include_letter.foldable.visible = false

        if typing_config.test_type == TypingData.TestType.Letters:
            groups.append(learn_letters)
            learn_letters.foldable.visible = true
            _rebuild_learn_letters(typing_data.languages[typing_config.test_language].alphabet, typing_config.get_language_config())
        else:
            learn_letters.foldable.visible = false

    groups.append(test_size)
    test_size.list.select(typing_config.test_size)


func _rebuild_include_letter(alphabet: PackedStringArray):
    include_letter.list.clear()
    include_letter.list.add_item("*")
    for letter in alphabet:
        include_letter.list.add_item(letter)
    include_letter.list.select(typing_config.include_letter + 1)


func _rebuild_learn_letters(alphabet: PackedStringArray, language_config: TypingConfigNaturalLanguage):
    learn_letters.list.clear()
    for letter in alphabet:
        var index = learn_letters.list.add_item(letter)
        learn_letters.list.set_item_tooltip(index, learn_letters_item_tooltip)
        if language_config.learn_letters.has(index):
            learn_letters.list.select(index, false)

    if language_config.learn_letters_target != -1:
        learn_letters.list.set_item_custom_bg_color(language_config.learn_letters_target, learn_letters_target_color)


func _unhandled_key_input(event: InputEvent) -> void:
    var event_keycode = event.keycode
    if event.echo or not event.is_pressed():
        return

    if event_keycode == KEY_ENTER:
        if is_focused_group_folded:
            unfocus()
        else:
            _change_focus(focused_group_index)

    if event_keycode == KEY_TAB:
        if is_focused_group_folded:
            if event.shift_pressed:
                _change_focus(focused_group_index - 1)
            else:
                _change_focus(focused_group_index + 1)
        else:
            _change_focus(focused_group_index)

    if event_keycode == KEY_UP:
        _change_selection(SIDE_TOP)
    if event_keycode == KEY_DOWN:
        _change_selection(SIDE_BOTTOM)
    if event_keycode == KEY_RIGHT:
        _change_selection(SIDE_RIGHT)
    if event_keycode == KEY_LEFT:
        _change_selection(SIDE_LEFT)


func _change_focus(new_focus_index: int):
    is_focused_group_folded = true
    focused_group_index = (new_focus_index + groups.size()) % groups.size()
    groups[focused_group_index].foldable.folded = false


func unfocus():
    is_focused_group_folded = false
    groups[focused_group_index].folded = true


func _change_selection(side: Side):
    var group = groups[focused_group_index]

    # we do not support other modes because ItemList is currently limited,
    # and I do not want to make custom ItemList yet
    if group.list.select_mode != ItemList.SelectMode.SELECT_SINGLE:
        return

    var select = func(item_index: int):
        group.list.select(item_index)
        group.list.item_selected.emit(item_index)
        # item_selected will fold, so unfold it again,
        # this is needed so mouse clicks fold, but keybord doesnt
        group.foldable.folded = false

    var item_count = group.list.item_count
    var max_columns = group.list.max_columns
    var selected_items = group.list.get_selected_items()
    var selected_item_index = selected_items[0]

    if max_columns == 1:
        if side == SIDE_TOP:
            select.call((selected_item_index - 1 + item_count) % item_count)
        if side == SIDE_BOTTOM:
            select.call((selected_item_index + 1 + item_count) % item_count)
    else:
        var row_count = int(ceil(item_count / float(max_columns)))
        var cell_count = row_count * max_columns
        if side == SIDE_LEFT:
            select.call((selected_item_index - 1 + item_count) % item_count)
        if side == SIDE_RIGHT:
            select.call((selected_item_index + 1 + item_count) % item_count)
        if side == SIDE_TOP:
            select.call((selected_item_index - max_columns + cell_count) % cell_count)
        if side == SIDE_BOTTOM:
            select.call((selected_item_index + max_columns + cell_count) % cell_count)


# this is needed to keep mouse clicks and keyboard input synchronised
func _on_folded(group: FoldableItemList, is_folded: bool):
    var index = groups.find(group)
    if index == -1:
        return
    if index == focused_group_index:
        is_focused_group_folded = !is_folded
    else:
        if not is_folded:
            focused_group_index = index
            is_focused_group_folded = true
