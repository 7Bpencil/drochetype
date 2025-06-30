extends Node

class_name Main

@export var goal_text: String
@export var letter_scene: PackedScene
@export var letter_size: Vector2i
@export var line_separation: int
@export var line_max_characters: int
@export var letter_settigs_goal: Resource
@export var letter_settigs_correct: Resource
@export var letter_settigs_wrong: Resource


var letters: Array[Node] = []
var is_shift_held: bool = false
var input_letter_index: int = 0


func _ready() -> void:
    letters.resize(goal_text.length())

    var i: int = 0
    var current_line_start_letter_index: int = 0
    var current_word_start_letter_index: int = 0
    var line_index: int = 0
    for goal_letter in goal_text:
        var line_current_letter_index: int = i - current_line_start_letter_index

        var letter = letter_scene.instantiate()
        letter.text = goal_letter
        letter.position = calculate_letter_position(line_current_letter_index, line_index)
        letters[i] = letter;
        add_child(letter)

        if line_current_letter_index == line_max_characters - 1:
            if goal_letter == " ":
                # if line ended on whitespace, good, no need to do anything
                line_index += 1
                current_line_start_letter_index = i + 1
            else:
                # otherwise, we need to move current word on next line
                line_index += 1
                current_line_start_letter_index = current_word_start_letter_index
                for k in range(current_word_start_letter_index, i + 1):
                    var current_word_letter = letters[k]
                    var line_current_word_letter_index = k - current_line_start_letter_index
                    current_word_letter.position = calculate_letter_position(line_current_word_letter_index, line_index)

        if goal_letter == " ":
            current_word_start_letter_index = i + 1

        i += 1


func calculate_letter_position(line_current_letter_index: int, line_index: int) -> Vector2i:
    var horizontal_position = letter_size.x * line_current_letter_index
    var vertical_position = (line_separation + letter_size.y) * line_index
    return Vector2i(horizontal_position, vertical_position)


var keys = {
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
    var event_keycode = event.keycode
    if event_keycode == KEY_SHIFT:
        if event.is_pressed():
            is_shift_held = true
        if event.is_released():
            is_shift_held = false

    if event.is_pressed() and keys.has(event_keycode):
        var key = keys[event_keycode]
        var key_char = key[1] if is_shift_held else key[0]
        if input_letter_index < letters.size():
            var goal_char = goal_text[input_letter_index]
            var letter = letters[input_letter_index]
            letter.label_settings = letter_settigs_correct if key_char == goal_char else letter_settigs_wrong
            letter.text = key_char
            input_letter_index += 1


func _process(_delta: float) -> void:
    pass
