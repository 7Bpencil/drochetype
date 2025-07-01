extends Node

class_name ScreenTyping

@export var letters_root: Control
@export var letter_scene: PackedScene
@export var letter_size: Vector2i
@export var line_separation: int
@export var line_max_characters: int
@export var letter_settings_goal: Resource
@export var letter_settings_correct: Resource
@export var letter_settings_wrong: Resource

signal show_typing_result(test_duration_msec: int, goal_text_characters: int, mistakes_count: int, letter_times: Array[int])

var is_running: bool = false
var letters: Array[Node] = []
var goal_letters: PackedStringArray = []
var letter_times: Array[int] = []
var previous_key_time: int = 0
var is_shift_held: bool = false
var input_letter_index: int = 0
var mistakes_count: int = 0
var start_test_time: int = 0
var hit_first_letter: bool = false

func start_test(words: PackedStringArray):
    var letters_count = get_letters_count(words)

    goal_letters.resize(letters_count)
    letters.resize(letters_count)
    letter_times.resize(letters_count)

    var i: int = 0
    var current_line_start_letter_index: int = 0
    var line_index: int = 0

    var current_line_length: int = 0
    for next_word in words:
        var next_word_length = next_word.length() + 1

        if current_line_length + next_word_length > line_max_characters:
            current_line_length = next_word_length
            current_line_start_letter_index = i
            line_index += 1
        else:
            current_line_length += next_word_length

        for next_letter in next_word:
            spawn_letter(i, next_letter, current_line_start_letter_index, line_index)
            i += 1

        spawn_letter(i, " ", current_line_start_letter_index, line_index)
        i += 1

    is_running = true

func get_letters_count(words: PackedStringArray) -> int:
    var letters_count: int = 0
    for word in words:
        letters_count += word.length()
    letters_count += words.size() # every word ends with whitespace, even the last one
    return letters_count

func spawn_letter(i: int, next_letter: String, current_line_start_letter_index: int, line_index: int) -> Node:
    var letter = letter_scene.instantiate()
    letter.text = next_letter
    letter.position = calculate_letter_position(i - current_line_start_letter_index, line_index)
    letters_root.add_child(letter)
    goal_letters[i] = next_letter
    letters[i] = letter
    return letter

func calculate_letter_position(current_line_letter_index: int, line_index: int) -> Vector2i:
    var horizontal_position = letter_size.x * current_line_letter_index
    var vertical_position = (line_separation + letter_size.y) * line_index
    return Vector2i(horizontal_position, vertical_position)

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

func _unhandled_key_input(event: InputEvent) -> void:
    if not is_running:
        return

    var current_key_time: int = Time.get_ticks_msec()
    if not hit_first_letter:
        start_test_time = current_key_time
        previous_key_time = current_key_time
        hit_first_letter = true

    var event_keycode = event.keycode
    if event_keycode == KEY_SHIFT:
        if event.is_pressed():
            is_shift_held = true
        if event.is_released():
            is_shift_held = false

    if event_keycode == KEY_BACKSPACE and event.is_pressed():
        input_letter_index -= 1
        var goal_char = goal_letters[input_letter_index]
        var letter = letters[input_letter_index]
        letter.label_settings = letter_settings_goal
        letter.text = goal_char
        previous_key_time = current_key_time

    if event.is_pressed() and keys.has(event_keycode) and input_letter_index < letters.size():
        var key = keys[event_keycode]
        var key_char = key[1] if is_shift_held else key[0]
        var goal_char = goal_letters[input_letter_index]
        var letter = letters[input_letter_index]

        letter_times[input_letter_index] = current_key_time - previous_key_time

        if key_char != goal_char:
            mistakes_count += 1
        if event_keycode == KEY_SPACE and key_char != goal_char:
            letter.label_settings = letter_settings_wrong
            letter.text = "_"
        else:
            letter.label_settings = letter_settings_correct if key_char == goal_char else letter_settings_wrong
            letter.text = key_char
        if input_letter_index == letters.size() - 1 and key_char == goal_char:
            var end_test_time = current_key_time
            var test_time = end_test_time - start_test_time
            var characters_count = letters.size()
            show_typing_result.emit(test_time, characters_count, mistakes_count, letter_times)

        input_letter_index += 1
        previous_key_time = current_key_time
