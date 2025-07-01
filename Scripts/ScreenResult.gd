extends Node

class_name ScreenResult

@export var label_wpm: Label
@export var label_cpm: Label
@export var label_accuracy: Label
@export var label_time: Label
@export var letter_time_graph_root: Control
@export var letter_time_graph_node: PackedScene

func show_result(test_duration_msec: int, goal_text_characters: int, mistakes_count: int, letter_times: Array[int]):
    var test_duration_sec = test_duration_msec / 1000.0
    var test_duration_min = test_duration_msec / (60 * 1000.0)
    var cpm = goal_text_characters / test_duration_min
    var wpm = cpm / 5.0
    var accuracy = (goal_text_characters - mistakes_count) / float(goal_text_characters) * 100

    label_cpm.text = "%s" % snappedf(cpm, 0.1)
    label_wpm.text = "%s" % snappedf(wpm, 0.1)
    label_accuracy.text = "%s%%" % snapped(accuracy, 0.1)
    label_time.text = "%ss" % snappedf(test_duration_sec, 0.1)

    print_letter_time_graph(letter_times)

func print_letter_time_graph(letter_times: Array[int]):
    var letters_count = letter_times.size() - 2 # first and last characters do not count
    var max_time: int = -1
    for i in range(letters_count):
        var letter_time = letter_times[i + 1]
        if letter_time > max_time:
            max_time = letter_time

    var total_size = letter_time_graph_root.size
    var node_width = total_size.x / float(letters_count)
    for i in range(letters_count):
        var letter_time = letter_times[i + 1]
        var node = letter_time_graph_node.instantiate()
        var node_height = total_size.y * letter_time / float(max_time)
        node.position = Vector2(node_width * i, total_size.y - node_height)
        node.size = Vector2(node_width, node_height)
        letter_time_graph_root.add_child(node)
