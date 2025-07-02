class_name ScreenResult extends Node


@export var label_wpm: Label
@export var label_cpm: Label
@export var label_accuracy_real: Label
@export var label_accuracy_result: Label
@export var label_time: Label
@export var letter_time_graph_root: Control
@export var letter_time_graph_node: PackedScene


func show_result(result: TypingResult):
    var result_keys_count = result.letter_results.size()
    var result_mistakes_count = result.letter_results.count(false)
    var result_accuracy = (result_keys_count - result_mistakes_count) / float(result_keys_count) * 100.0

    var test_duration_sec = result.test_duration_msec / 1000.0
    var test_duration_min = result.test_duration_msec / (60.0 * 1000.0)
    var real_cpm = result.real_keys_count / test_duration_min
    var real_wpm = real_cpm / 5.0
    var real_accuracy = (result.real_keys_count - result.real_mistakes_count) / float(result.real_keys_count) * 100.0

    label_cpm.text = "%d" % real_cpm
    label_wpm.text = "%d" % real_wpm
    label_accuracy_real.text = "%d%%" % real_accuracy
    label_accuracy_result.text = "%d%%" % result_accuracy
    label_time.text = "%ds" % test_duration_sec













func print_letter_time_graph(goal_words: PackedStringArray, letter_times: Array[int]):
    var words_data = calculate_words_data(goal_words,  letter_times)

    # thanks Godot for not having float.Min and float.Max
    var max_word_cpm: float = -1
    var min_word_cpm: float = 100_000
    var sum_cpm: float = 0
    for word_data in words_data:
        sum_cpm += word_data.word_cpm
        if word_data.word_cpm > max_word_cpm:
            max_word_cpm = word_data.word_cpm
        if word_data.word_cpm < min_word_cpm:
            min_word_cpm = word_data.word_cpm

    var words_count = words_data.size()
    var average_cpm = sum_cpm / words_count
    var total_size = letter_time_graph_root.size
    var node_width = total_size.x / float(words_count)
    for i in range(words_count):
        var word_data = words_data[i]
        var node = letter_time_graph_node.instantiate()
        var node_height = total_size.y * word_data.word_cpm / max_word_cpm
        node.position = Vector2(node_width * i, total_size.y - node_height)
        node.size = Vector2(node_width, node_height)
        letter_time_graph_root.add_child(node)

    label_cpm.text = "%s" % snappedf(average_cpm, 0.1)

class WordData:
    var word_time: int
    var word_cpm: float

    func _init(word_time: int, word_cpm: float):
        self.word_time = word_time
        self.word_cpm = word_cpm

func calculate_words_data(goal_words: PackedStringArray, letter_times: Array[int]) -> Array[WordData]:
    var words_data: Array[WordData] = []
    words_data.resize(goal_words.size())

    var letter_index: int = 0
    for word_index in range(goal_words.size()):
        var goal_word = goal_words[word_index]
        var goal_word_time: int = 0
        var goal_word_length = goal_word.length()
        for k in range(goal_word_length):
            goal_word_time += letter_times[letter_index]
            letter_index += 1
        letter_index += 1

        # first letter of first word has time 0, so remove that letter from calculation
        var goal_word_effective_length = goal_word_length if word_index != 0 else goal_word_length - 1
        var goal_word_cpm: float = goal_word_effective_length / (goal_word_time / 1000.0 / 60.0)
        words_data[word_index] = WordData.new(goal_word_time, goal_word_cpm)

    return words_data
