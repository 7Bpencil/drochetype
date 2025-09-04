class_name TypingDataNaturalLanguageConfig


var name: String
var alphabet: String
var bigrams: String
var trigrams: String
var words_very_common: String
var words_common: String
var words_rare: String
var words_very_rare: String


static func from_json_dict(json_dict: Dictionary) -> TypingDataNaturalLanguageConfig:
    var result = TypingDataNaturalLanguageConfig.new()
    result.name = json_dict["name"]
    result.alphabet = json_dict["alphabet"]
    result.bigrams = json_dict["bigrams"]
    result.trigrams = json_dict["trigrams"]
    result.words_very_common = json_dict["words_very_common"]
    result.words_common = json_dict["words_common"]
    result.words_rare = json_dict["words_rare"]
    result.words_very_rare = json_dict["words_very_rare"]
    return result
