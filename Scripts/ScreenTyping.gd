class_name ScreenTyping extends Node


@export var letters_root: Control
@export var letter_scene: PackedScene
@export var letter_size: Vector2i
@export var line_separation: int
@export var max_line_characters: int
@export var max_lines: int
@export var letter_settings_goal: Resource
@export var letter_settings_correct: Resource
@export var letter_settings_wrong: Resource


signal show_typing_result(result: TypingResult)
signal restart_test


var english_1k: PackedStringArray
var english_450k: PackedStringArray
var letters: Array[Node] = []

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

var goal_words: PackedStringArray


func _ready() -> void:
    _load_corpuses()
    var max_letters_count = max_line_characters * max_lines

    letters.resize(max_letters_count)
    goal_letters.resize(max_letters_count)
    letter_times.resize(max_letters_count)
    letter_results.resize(max_letters_count)

    for i in range(max_letters_count):
        _spawn_letter(i)


func _load_corpuses():
    english_1k = _load_language("res://Data/english_1k.txt")
    english_450k = _load_language("res://Data/english_450k.txt")


func _load_language(path: String) -> PackedStringArray:
    var words_file = FileAccess.open(path, FileAccess.READ)
    var words_file_content = words_file.get_as_text()
    var first_few_words = words_file_content.left(50) # lets hope there wont be 50 char long words...
    if first_few_words.contains("\r\n"):
        return words_file_content.split("\r\n")
    if first_few_words.contains("\n"):
        return words_file_content.split("\n")
    return []


func start_test():
    goal_words = _generate_new_words(english_450k, 10)
    var goal_letters_count = _get_letters_count(goal_words)

    goal_letters.resize(goal_letters_count)
    letter_times.resize(goal_letters_count)
    letter_results.resize(goal_letters_count)

    hit_first_letter = false
    input_letter_index = 0
    real_keys_count = 0
    real_mistakes_count = 0

    var i: int = 0
    var current_line_start_letter_index: int = 0
    var line_index: int = 0
    var current_line_length: int = 0

    for wi in range(goal_words.size()):
        var end_whitespace: bool = wi != goal_words.size() - 1 # last word does not have whitespace on the end
        var next_word = goal_words[wi]
        var next_word_length = next_word.length() + 1 if end_whitespace else next_word.length()

        if current_line_length + next_word_length > max_line_characters:
            current_line_length = next_word_length
            current_line_start_letter_index = i
            line_index += 1
        else:
            current_line_length += next_word_length

        for next_letter in next_word:
            _set_letter(i, next_letter, current_line_start_letter_index, line_index)
            i += 1

        if end_whitespace:
            _set_letter(i, " ", current_line_start_letter_index, line_index)
            i += 1

    for k in range(i, letters.size()):
        _clear_letter(k)

    is_running = true


func _generate_new_words(all_words: PackedStringArray, words_count: int) -> PackedStringArray:
    var result: Array[String] = []
    result.resize(words_count)
    for i in range(words_count):
        var random_index = randi_range(0, all_words.size() - 1)
        var random_word = all_words[random_index]
        result[i] = random_word
    return result


func _get_letters_count(words: PackedStringArray) -> int:
    var letters_count: int = 0
    for word in words:
        letters_count += word.length()
    letters_count += words.size() - 1 # put whitespaces between words
    return letters_count


func _spawn_letter(i: int):
    var letter = letter_scene.instantiate()
    letter.text = ""
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
        restart_test.emit()
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
            var result = TypingResult.new(goal_words, test_time, real_keys_count, real_mistakes_count, letter_times, letter_results)
            show_typing_result.emit(result)

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
