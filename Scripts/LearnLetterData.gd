class_name LearnLetterData extends Resource


@export var results: Array[bool]
@export var times: Array[int]

const max_window_width: int = 10


func _init():
    results = []
    times = []


func push_new_value(result: bool, time: int):
    _push_new_value_to_stack(results, result)
    if result:
        _push_new_value_to_stack(times, time) # we don't care about timing if it was mistake


func _push_new_value_to_stack(stack, value):
    if stack.size() < max_window_width:
        stack.append(value)
    else:
        stack.remove_at(0)
        stack.append(value)


func get_average_accuracy() -> float:
    if results.size() == 0:
        return 0.0
    var correct_count: float = results.count(true)
    return correct_count / results.size()


func get_average_time() -> float:
    if times.size() == 0:
        return 0.0
    var sum: float = 0.0
    for time in times:
        sum += time
    return sum / times.size()
