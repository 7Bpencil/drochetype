extends Node

class_name ScreenResult

@export var label_wpm: Label
@export var label_cpm: Label
@export var label_accuracy: Label
@export var label_time: Label

func show_result(test_duration_msec: int, goal_text_characters: int, mistakes_count: int):
    var test_duration_sec = test_duration_msec / 1000.0
    var test_duration_min = test_duration_msec / (60 * 1000.0)
    var cpm = goal_text_characters / test_duration_min
    var wpm = cpm / 5.0
    var accuracy = (goal_text_characters - mistakes_count) / float(goal_text_characters) * 100

    label_cpm.text = "%s" % snappedf(cpm, 0.1)
    label_wpm.text = "%s" % snappedf(wpm, 0.1)
    label_accuracy.text = "%s%%" % snapped(accuracy, 0.1)
    label_time.text = "%ss" % snappedf(test_duration_sec, 0.1)
