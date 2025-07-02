class_name TypingResult

var goal_words: PackedStringArray
var test_duration_msec: int
var real_keys_count: int
var real_mistakes_count: int
var letter_times: Array[int]
var letter_results: Array[bool]

func _init(
    goal_words: PackedStringArray,
    test_duration_msec: int,
    real_keys_count: int,
    real_mistakes_count: int,
    letter_times: Array[int],
    letter_results: Array[bool]):

    self.goal_words = goal_words
    self.test_duration_msec = test_duration_msec
    self.real_keys_count = real_keys_count
    self.real_mistakes_count = real_mistakes_count
    self.letter_times = letter_times
    self.letter_results = letter_results
