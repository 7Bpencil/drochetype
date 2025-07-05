class_name ScreenTyping extends Node


@export var letters_root: Control
@export var letter_scene: PackedScene
@export var cursor_scene: PackedScene
@export var line_separation: int
@export var max_line_characters: int
@export var max_lines: int
@export var letter_settings_goal: Resource
@export var letter_settings_correct: Resource
@export var letter_settings_wrong: Resource


signal show_typing_result(result: TypingResult)
signal restart_test

var typing_data: TypingData
var max_letters_count: int
var letters: Array[Control] = []
var letter_size: Vector2
var cursor: Control
var cursor_size: Vector2

var goal_letters: PackedStringArray = []
var letter_times: Array[int] = []
var letter_results: Array[bool] = []

var is_shift_held: bool = false

var is_running: bool = false
var is_finished: bool = false
var hit_first_letter: bool = false
var input_letter_index: int = 0
var real_keys_count: int = 0
var real_mistakes_count: int = 0
var start_test_time: int = 0
var previous_key_time: int = 0

var typing_config: TypingConfig


func _ready() -> void:
    max_letters_count = max_line_characters * max_lines

    letters.resize(max_letters_count)
    goal_letters.resize(max_letters_count)
    letter_times.resize(max_letters_count)
    letter_results.resize(max_letters_count)

    _spawn_cursor()
    for i in range(max_letters_count):
        _spawn_letter(i)


func set_typing_data(data: TypingData):
    typing_data = data


func start_test(new_typing_config: TypingConfig):
    typing_config = new_typing_config

    var test_layout = _generate_new_words(typing_config)

    goal_letters.resize(test_layout.letters_count)
    letter_times.resize(test_layout.letters_count)
    letter_results.resize(test_layout.letters_count)

    hit_first_letter = false
    input_letter_index = 0
    real_keys_count = 0
    real_mistakes_count = 0

    var i: int = 0
    var lines_count = test_layout.lines.size()

    for line_index in range(lines_count):
        var line_words = test_layout.lines[line_index]
        var line_words_count = line_words.size()
        var current_line_start_letter_index = i

        for word_index in range(line_words_count):
            var next_word = line_words[word_index]

            for next_letter in next_word:
                _set_letter(i, next_letter, current_line_start_letter_index, line_index)
                i += 1

            # put space after every word except very last one
            if not (line_index == lines_count - 1 and word_index == line_words_count - 1):
                _set_letter(i, " ", current_line_start_letter_index, line_index)
                i += 1

    for k in range(i, letters.size()):
        _clear_letter(k)

    _set_cursor_position(0, test_layout.letters_count)

    is_running = true
    is_finished = false


func _generate_new_words(typing_config: TypingConfig) -> TypingLayout:
    var all_words = typing_data.english_words_map[typing_config.words_rarity]
    var test_max_lines_count: int = floor(max_lines * typing_data.test_size_map[typing_config.test_size]) as int

    var result_lines: Array[Array] = []
    var result_line_words: Array[String] = []

    var line_index: int = 0
    var current_line_length: int = 0
    var test_current_letters_count: int = 0

    while true:
        var random_index = randi_range(0, all_words.size() - 1)
        var next_word = all_words[random_index]
        var next_word_length = next_word.length() + 1 # put space after every word

        if test_current_letters_count + next_word_length > max_letters_count:
            break
        if current_line_length + next_word_length > max_line_characters:
            if line_index + 1 < test_max_lines_count:
                current_line_length = next_word_length
                line_index += 1

                result_lines.append(result_line_words)
                result_line_words = []
            else:
                break
        else:
            current_line_length += next_word_length

        test_current_letters_count += next_word_length
        result_line_words.append(next_word)

    result_lines.append(result_line_words)

    var result = TypingLayout.new()
    result.lines = result_lines
    result.letters_count = test_current_letters_count - 1 # remove space after last word

    return result


func _spawn_cursor():
    cursor = cursor_scene.instantiate()
    cursor_size = cursor.size
    letters_root.add_child(cursor)


func _spawn_letter(i: int):
    var letter = letter_scene.instantiate()
    letter.text = ""
    letter_size = letter.size
    letters_root.add_child(letter)
    letters[i] = letter


func _set_letter(i: int, next_letter: String, current_line_start_letter_index: int, line_index: int):
    var letter = letters[i]
    letter.text = next_letter
    letter.position = _calculate_letter_position(i - current_line_start_letter_index, line_index)
    letter.label_settings = letter_settings_goal
    goal_letters[i] = next_letter


func _clear_letter(i: int):
    var letter = letters[i]
    letter.text = ""


func _set_cursor_position(i: int, goal_letters_count: int):
    if i < goal_letters_count:
        var letter_position = letters[i].position
        cursor.position = Vector2(letter_position.x - cursor_size.x, letter_position.y)
        cursor.show()
    else:
        cursor.hide()


func _calculate_letter_position(current_line_letter_index: int, line_index: int) -> Vector2i:
    var horizontal_position = letter_size.x * current_line_letter_index
    var vertical_position = (line_separation + letter_size.y) * line_index
    return Vector2i(horizontal_position, vertical_position)


func _unhandled_key_input(event: InputEvent) -> void:
    var event_keycode = event.keycode

    if event_keycode == KEY_SHIFT:
        if event.is_pressed():
            is_shift_held = true
        if event.is_released():
            is_shift_held = false
        return

    if not is_running:
        return

    if event_keycode == KEY_SPACE and event.is_pressed() and is_finished:
        is_running = false
        is_finished = false
        restart_test.emit(typing_config)
        return

    if is_finished:
        return

    var current_key_time: int = Time.get_ticks_msec()

    if event_keycode == KEY_BACKSPACE and event.is_pressed() and input_letter_index > 0:
        input_letter_index -= 1
        var goal_char = goal_letters[input_letter_index]
        var letter = letters[input_letter_index]
        letter.label_settings = letter_settings_goal
        letter.text = goal_char
        _set_cursor_position(input_letter_index, goal_letters.size())
        previous_key_time = current_key_time
        return

    if keys.has(event_keycode) and event.is_pressed() and input_letter_index < goal_letters.size():
        if not hit_first_letter:
            start_test_time = current_key_time
            hit_first_letter = true

        var key = keys[event_keycode]
        var key_char = key[1] if is_shift_held else key[0]
        var goal_char = goal_letters[input_letter_index]
        var letter = letters[input_letter_index]
        var is_correct = key_char == goal_char

        letter_times[input_letter_index] = current_key_time - previous_key_time
        letter_results[input_letter_index] = is_correct

        real_keys_count += 1
        if not is_correct:
            real_mistakes_count += 1
        if event_keycode == KEY_SPACE and not is_correct:
            letter.label_settings = letter_settings_wrong
            letter.text = "_"
        else:
            letter.label_settings = letter_settings_correct if is_correct else letter_settings_wrong
            letter.text = key_char
        if input_letter_index == goal_letters.size() - 1 and is_correct:
            is_finished = true
            var end_test_time = current_key_time
            var test_time = end_test_time - start_test_time
            var result = TypingResult.new(test_time, real_keys_count, real_mistakes_count, letter_times, letter_results)
            show_typing_result.emit(result)

        _set_cursor_position(input_letter_index + 1, goal_letters.size())

        input_letter_index += 1
        previous_key_time = current_key_time
        return


const keys = {
    # alphabet
    KEY_A : ["a", "A"],
    KEY_B : ["b", "B"],
    KEY_C : ["c", "C"],
    KEY_D : ["d", "D"],
    KEY_E : ["e", "E"],
    KEY_F : ["f", "F"],
    KEY_G : ["g", "G"],
    KEY_H : ["h", "H"],
    KEY_I : ["i", "I"],
    KEY_J : ["j", "J"],
    KEY_K : ["k", "K"],
    KEY_L : ["l", "L"],
    KEY_M : ["m", "M"],
    KEY_N : ["n", "N"],
    KEY_O : ["o", "O"],
    KEY_P : ["p", "P"],
    KEY_Q : ["q", "Q"],
    KEY_R : ["r", "R"],
    KEY_S : ["s", "S"],
    KEY_T : ["t", "T"],
    KEY_U : ["u", "U"],
    KEY_V : ["v", "V"],
    KEY_W : ["w", "W"],
    KEY_X : ["x", "X"],
    KEY_Y : ["y", "Y"],
    KEY_Z : ["z", "Z"],
    # numbers
    KEY_0 : ["0", ")"],
    KEY_1 : ["1", "!"],
    KEY_2 : ["2", "@"],
    KEY_3 : ["3", "#"],
    KEY_4 : ["4", "$"],
    KEY_5 : ["5", "%"],
    KEY_6 : ["6", "^"],
    KEY_7 : ["7", "&"],
    KEY_8 : ["8", "*"],
    KEY_9 : ["9", "("],
    # special
    KEY_SPACE : [" ", " "],
}
