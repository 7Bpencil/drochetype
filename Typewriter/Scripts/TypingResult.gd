class_name TypingResult


var test_duration_msec: int
var real_keys_count: int
var real_mistakes_count: int


func _init(
    test_duration_msec: int,
    real_keys_count: int,
    real_mistakes_count: int):

    self.test_duration_msec = test_duration_msec
    self.real_keys_count = real_keys_count
    self.real_mistakes_count = real_mistakes_count
