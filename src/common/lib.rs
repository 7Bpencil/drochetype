use serde::{
    Deserialize, Serialize,
};
use std::{
    collections::HashMap,
};

#[derive(Serialize, Deserialize)]
#[derive(Hash, Eq, PartialEq, Copy, Clone, Debug)]
pub enum WordsRarity {
    VeryCommon,
    Common,
    Rare,
    VeryRare,
}

#[derive(Serialize, Deserialize)]
#[derive(Hash, Eq, PartialEq, Copy, Clone, Debug)]
pub enum TestSize {
    VerySmall,
    Small,
    Medium,
    Large,
}

#[derive(Serialize, Deserialize)]
pub struct Data_Intermediate {
    pub numbers: Vec<char>,
    pub symbols: Vec<char>,
    pub natural_languages: Vec<NaturalLanguageData_Intermediate>,
    pub test_sizes: HashMap<TestSize, usize>,
}

#[derive(Serialize, Deserialize)]
pub struct NaturalLanguageData_Intermediate {
    pub name: String,
    pub alphabet: Vec<char>,
    pub bigrams: Vec<String>,
    pub trigrams: Vec<String>,
    pub words: HashMap<WordsRarity, Vec<String>>,
}
