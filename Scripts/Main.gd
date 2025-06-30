extends Node

class_name Main

@export var goal_text: String
@export var letter_scene: PackedScene
@export var letter_size: Vector2i
@export var line_separation: int
@export var line_max_characters: int


var letters: Array[Node] = []


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


func _process(delta: float) -> void:
    pass
