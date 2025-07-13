class_name ScreenTyping extends Node


@export var timer: Label
@export var timer_setting_waiting: Resource
@export var timer_setting_running: Resource
@export var timer_setting_finished: Resource
@export var letters_root: Control
@export var letter_scene: PackedScene
@export var cursor_scene: PackedScene
@export var line_separation: int
@export var max_line_characters: int
@export var max_lines: int
@export var letter_settings_goal: Resource
@export var letter_settings_correct: Resource
@export var letter_settings_wrong: Resource


signal show_test_result(result: TypingResult)
signal generate_new_test()
signal reset_current_test()
signal update_letter_stats()


var typing_data: TypingData
var typing_config: TypingConfig

var test_generator: TestGenerator
var max_letters_count: int
var letters: Array[Control] = []
var letter_size: Vector2
var cursor: Control
var cursor_size: Vector2

var goal_letters: PackedStringArray = []

var is_shift_held: bool = false

var is_running: bool = false
var is_finished: bool = false
var hit_first_letter: bool = false
var input_letter_index: int = 0
var real_keys_count: int = 0
var real_mistakes_count: int = 0
var start_test_time: int = 0
var previous_key_time: int = 0
var timer_previous_seconds: int = -1

var test_layout: TypingLayout


func _ready() -> void:
    max_letters_count = max_line_characters * max_lines

    letters.resize(max_letters_count)
    goal_letters.resize(max_letters_count)

    _spawn_cursor()
    for i in range(max_letters_count):
        _spawn_letter(i)


func set_data(data: TypingData, config: TypingConfig):
    typing_data = data
    typing_config = config
    test_generator = TestGenerator.new(typing_data, typing_config)


func start_test():
    test_layout = _generate_new_words()

    goal_letters.resize(test_layout.letters_count)

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
    _timer_set_time(0)
    _timer_set_state(TimerState.Waiting)

    is_running = true
    is_finished = false


func reset_test():
    for i in range(input_letter_index):
        _reset_letter(i, goal_letters[i])

    hit_first_letter = false
    input_letter_index = 0
    real_keys_count = 0
    real_mistakes_count = 0

    _set_cursor_position(0, test_layout.letters_count)
    _timer_set_time(0)
    _timer_set_state(TimerState.Waiting)

    is_running = true
    is_finished = false


func _generate_new_words() -> TypingLayout:
    test_generator.generate_next_test()

    var test_max_lines_count: int = min(max_lines, typing_data.test_sizes[typing_config.test_size])

    var result_lines: Array[Array] = []
    var result_line_words: Array[String] = []

    var line_index: int = 0
    var current_line_length: int = 0
    var test_current_letters_count: int = 0

    while true:
        var next_word = test_generator.get_next_word()
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


func _reset_letter(i: int, next_letter: String):
    var letter = letters[i]
    letter.text = next_letter
    letter.label_settings = letter_settings_goal


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
        generate_new_test.emit()
        return

    if event_keycode == KEY_ESCAPE and event.is_pressed():
        if input_letter_index == 0:
            generate_new_test.emit()
        else:
            reset_current_test.emit()

    if is_finished:
        return

    var current_key_time: int = Time.get_ticks_msec()

    if event_keycode == KEY_BACKSPACE and event.is_pressed():
        if input_letter_index == 0:
            return
        if input_letter_index == 1:
            reset_current_test.emit()
        else:
            input_letter_index -= 1
            previous_key_time = current_key_time
            _reset_letter(input_letter_index, goal_letters[input_letter_index])
            _set_cursor_position(input_letter_index, goal_letters.size())
            return

    if typing_data.keycodes.has(event_keycode) and event.is_pressed() and input_letter_index < goal_letters.size():
        if not hit_first_letter:
            start_test_time = current_key_time
            hit_first_letter = true
            _timer_set_state(TimerState.Running)

        var key_char = "%c" % event.unicode
        var goal_char = goal_letters[input_letter_index]
        var letter = letters[input_letter_index]
        var is_correct = key_char == goal_char
        var key_time = current_key_time - previous_key_time

        real_keys_count += 1
        if not is_correct:
            real_mistakes_count += 1

        typing_config.on_letter_typed(goal_char, is_correct, key_time, typing_data)
        update_letter_stats.emit()

        if event_keycode == KEY_SPACE and not is_correct:
            letter.label_settings = letter_settings_wrong
            letter.text = "_"
        else:
            letter.label_settings = letter_settings_correct if is_correct else letter_settings_wrong
            letter.text = key_char

        if input_letter_index == goal_letters.size() - 1 and is_correct:
            is_finished = true
            var test_time = current_key_time - start_test_time
            var result = TypingResult.new(test_time, real_keys_count, real_mistakes_count)
            _timer_set_time(test_time)
            _timer_set_state(TimerState.Finished)
            show_test_result.emit(result)

        previous_key_time = current_key_time
        input_letter_index += 1
        _set_cursor_position(input_letter_index, goal_letters.size())

        return


func _process(delta):
    if is_running and hit_first_letter and not is_finished:
        var time = Time.get_ticks_msec()
        _timer_set_time(time - start_test_time)


func _timer_set_time(time_msec: int):
    var sec: int = floor(time_msec / 1000.0) as int
    if sec == timer_previous_seconds:
        return

    timer_previous_seconds = sec
    var min: int = sec / 60
    var sec_remaining = sec - min * 60
    var time_format = "%02d:%02d" % [min, sec_remaining]
    timer.text = time_format


func _timer_set_state(state: TimerState):
    match state:
        TimerState.Waiting:
            timer.label_settings = timer_setting_waiting
        TimerState.Running:
            timer.label_settings = timer_setting_running
        TimerState.Finished:
            timer.label_settings = timer_setting_finished


enum TimerState {
    Waiting,
    Running,
    Finished
}
