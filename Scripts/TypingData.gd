class_name TypingData

enum TestType {
    Bigrams = 0,
    Trigrams = 1,
    Words = 2,
}

enum WordsRarity {
    VeryCommon = 0,
    Common = 1,
    Rare = 2,
    VeryRare = 3,
}

enum TestSize {
    Small = 0,
    Medium = 1,
    Large = 2,
    ExtraLarge = 3,
}

var english_words_map: Dictionary
var test_size_map: Dictionary
