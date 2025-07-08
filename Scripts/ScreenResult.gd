class_name ScreenResult extends Node


@export var label_wpm: Label
@export var label_accuracy_real: Label


func show_result(result: TypingResult):
    var test_duration_min = result.test_duration_msec / (60.0 * 1000.0)
    var real_cpm = result.real_keys_count / test_duration_min
    var real_wpm = real_cpm / 5.0
    var real_accuracy = (result.real_keys_count - result.real_mistakes_count) / float(result.real_keys_count) * 100.0

    label_wpm.text = "%d" % real_wpm
    label_wpm.tooltip_text = "%d cpm" % real_cpm
    label_accuracy_real.text = "%d%%" % real_accuracy
