use common::*;
use serde::{
    Deserialize,
    de::DeserializeOwned,
};
use std::{
    collections::HashMap,
    path::Path,
};

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

fn main() {
    let data = load_data();
    let data_serialized = rmp_serde::encode::to_vec(&data).expect("failed to serialize");
    let compression_level = 7; // tested every level, this one was the last that gave size improvements
    let data_serialized_compressed = miniz_oxide::deflate::compress_to_vec(&data_serialized, compression_level);
    let output_path = "data_intermediate.bin";
    std::fs::write(output_path, data_serialized_compressed).expect("failed to write file");
    println!("serialized data into {}", output_path);
}

fn load_data() -> Data_Intermediate {
    let root = Path::new("data");
    let numbers = load_from_json_file::<Vec<char>>(&root.join("numbers.json"));
    let symbols = load_from_json_file::<Vec<char>>(&root.join("symbols.json"));
    let languages = load_from_json_file::<Vec<DataLanguage>>(&root.join("languages.json"));
    let mut natural_languages = Vec::with_capacity(languages.len());

    for language in languages {
        let name = language.name;
        let alphabet = load_from_json_file::<Vec<char>>(&root.join(language.alphabet));
        let bigrams = load_from_json_file::<Vec<String>>(&root.join(language.bigrams));
        let trigrams = load_from_json_file::<Vec<String>>(&root.join(language.trigrams));

        let mut words_very_common = load_monkeytype_words(&root.join(language.words_very_common));
        let mut words_common = load_monkeytype_words(&root.join(language.words_common));
        let mut words_rare = load_monkeytype_words(&root.join(language.words_rare));
        let mut words_very_rare = load_monkeytype_words(&root.join(language.words_very_rare));

        remove_one_letter_words(&mut words_very_common);
        remove_one_letter_words(&mut words_common);
        remove_one_letter_words(&mut words_rare);
        remove_one_letter_words(&mut words_very_rare);

        let words = HashMap::from([
            (WordsRarity::VeryCommon, words_very_common),
            (WordsRarity::Common, words_common),
            (WordsRarity::Rare, words_rare),
            (WordsRarity::VeryRare, words_very_rare),
        ]);

        natural_languages.push(NaturalLanguageData_Intermediate {
            name,
            alphabet,
            bigrams,
            trigrams,
            words,
        });
    }

    Data_Intermediate {
        numbers,
        symbols,
        natural_languages,
        test_sizes: HashMap::from([
            (TestSize::VerySmall, 1),
            (TestSize::Small, 3),
            (TestSize::Medium, 6),
            (TestSize::Large, 12),
        ])
    }
}

fn load_from_json_file<T: DeserializeOwned>(path: &Path) -> T {
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
        if words[i].chars().count() < 2 {
            words.swap_remove(i);
        } else {
            i += 1;
        }
    }
}
