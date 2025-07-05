class_name TypingData

enum TestType {
    Bigrams,
    Trigrams,
    Words,
}

enum WordsRarity {
    VeryCommon,
    Common,
    Rare,
    VeryRare,
}

enum TestSize {
    VerySmall,
    Small,
    Medium,
    Large,
}

var english_bigrams: PackedStringArray
var english_trigrams: PackedStringArray
var english_words: Dictionary
var test_sizes: Dictionary
