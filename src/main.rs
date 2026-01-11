use serde::{Deserialize, Serialize};
use serde::de::DeserializeOwned;
use std::path::Path;
use std::collections::{HashMap, HashSet};

enum TestLanguage {
    Numbers,
    Symbols,
    Natural // there can be multiple natural languages, we assume that all of them are placed after symbols language
}

enum TestType {
    Letters,
    Bigrams,
    Trigrams,
    Words,
}

#[derive(Hash)]
#[derive(Eq)]
#[derive(PartialEq)]
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

#[derive(Deserialize, Debug)]
struct DataLanguage {
    name: String,
    alphabet: String,
    bigrams: String,
    trigrams: String,
    words_very_common: String,
    words_common: String,
    words_rare: String,
    words_very_rare: String
}

#[derive(Deserialize, Debug)]
struct DataMonkeytype {
    words: Vec<String>
}

struct TypingDataNaturalLanguage {
    name: String,
    alphabet: Vec<char>,
    alphabet_dict: HashMap<char, usize>,
    bigrams: Vec<String>,
    trigrams: Vec<String>,
    words: HashMap<WordsRarity, Vec<String>>,
    words_per_letter: HashMap<WordsRarity, HashMap<char, Vec<usize>>>,
}

fn main() {
    get_config();
}

fn get_config() {
    let root = Path::new("data");
    let numbers = load_from_json::<Vec<String>>(&root.join("numbers.json"));
    let symbols = load_from_json::<Vec<String>>(&root.join("symbols.json"));
    let languages = load_from_json::<Vec<DataLanguage>>(&root.join("languages.json"));
    let mut natural_languages_data = Vec::with_capacity(languages.len());

    for language in languages {
        let name = language.name;
        let alphabet = load_from_json::<Vec<char>>(&root.join(language.alphabet));
        let alphabet_dict = build_alphabet_dict(&alphabet);
        let bigrams = load_from_json::<Vec<String>>(&root.join(language.bigrams));
        let trigrams = load_from_json::<Vec<String>>(&root.join(language.trigrams));

        let mut words_very_common = load_monkeytype_words(&root.join(language.words_very_common));
        let mut words_common = load_monkeytype_words(&root.join(language.words_common));
        let mut words_rare = load_monkeytype_words(&root.join(language.words_rare));
        let mut words_very_rare = load_monkeytype_words(&root.join(language.words_very_rare));

        remove_one_letter_words(&mut words_very_common);
        remove_one_letter_words(&mut words_common);
        remove_one_letter_words(&mut words_rare);
        remove_one_letter_words(&mut words_very_rare);

        let words_per_letter = HashMap::from([
            (WordsRarity::VeryCommon, build_letter_to_words_dict(&words_very_common, &alphabet)),
            (WordsRarity::Common, build_letter_to_words_dict(&words_common, &alphabet)),
            (WordsRarity::Rare, build_letter_to_words_dict(&words_rare, &alphabet)),
            (WordsRarity::VeryRare, build_letter_to_words_dict(&words_very_rare, &alphabet)),
        ]);

        let words = HashMap::from([
            (WordsRarity::VeryCommon, words_very_common),
            (WordsRarity::Common, words_common),
            (WordsRarity::Rare, words_rare),
            (WordsRarity::VeryRare, words_very_rare),
        ]);

        natural_languages_data.push(TypingDataNaturalLanguage {
            name,
            alphabet,
            alphabet_dict,
            bigrams,
            trigrams,
            words,
            words_per_letter,
        });
    }
}

fn load_from_json<T: DeserializeOwned>(path: &Path) -> T {
    let bytes = std::fs::read(path).unwrap();
    let data: T = serde_json::from_slice(&bytes).unwrap();
    data
}

fn load_monkeytype_words(path: &Path) -> Vec<String> {
    // some words have capital letters in them, I don't like it.
    // so, just lower an entire file, its much faster than lowering each word separately
    let text = std::fs::read_to_string(path).unwrap();
    let text_lowercase = text.to_lowercase();
    let data: DataMonkeytype = serde_json::from_str(&text_lowercase).unwrap();
    data.words
}

fn remove_one_letter_words(words: &mut Vec<String>) {
    let mut i = 0;
    while i < words.len() {
        if words[i].len() < 2 {
            words.swap_remove(i);
        } else {
            i += 1;
        }
    }
}

fn build_alphabet_dict(alphabet: &Vec<char>) -> HashMap<char, usize> {
    let mut result = HashMap::new();
    for (i, letter) in alphabet.iter().enumerate() {
        result.insert(letter.clone(), i);
    }
    result
}

fn build_letter_to_words_dict(words: &Vec<String>, alphabet: &Vec<char>) -> HashMap<char, Vec<usize>> {
    let mut result = HashMap::new();

    for letter in alphabet {
        result.insert(letter.clone(), Vec::new());
    }

    let mut included_letters = HashSet::new();
    for (word_index, word) in words.iter().enumerate() {
        included_letters.clear();
        for letter in word.chars() {
            // prevent including word multiple times if it has repeating characters
            if included_letters.contains(&letter) {
                continue;
            }

            if let Some(letter_words) = result.get_mut(&letter) {
                letter_words.push(word_index);
                included_letters.insert(letter);
            }
        }
    }

    result
}
