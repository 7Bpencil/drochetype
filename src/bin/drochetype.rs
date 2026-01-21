// TODO finalize UI, serialize data from json and embed it into binary
use common::*;
use std::{
    collections::{HashMap, HashSet},
    time::Instant,
};
use spdlog::{prelude::*, sink::FileSink};
use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyModifiers};
use rand::prelude::SliceRandom;
use ratatui::{
    layout::{Rect, Position},
    style::{Stylize, Color, Style, Modifier},
    text::{Span, Line, Text},
    widgets::{Block, Paragraph, Borders, Clear},
    DefaultTerminal, Frame,
};

const MAX_LINE_LENGTH: usize = 45; // TODO add different widths: narrow, medium, wide
const INCLUDE_LETTER_UI_MATRIX_WIDTH: usize = 7; // TODO maybe this should depend on localization (7 wont fit with some languages)?

fn get_index<T: PartialEq + Copy>(current_item: T, items: &[T]) -> usize {
    items.iter().position(|v| *v == current_item).expect("current item is not in items vec")
}

fn get_next<T: PartialEq + Copy>(current_item: T, items: &[T]) -> T {
    let index = get_index(current_item, items);
    let next_index = loop_index_forward(index, items.len());
    items[next_index]
}

fn get_previous<T: PartialEq + Copy>(current_item: T, items: &[T]) -> T {
    let index = get_index(current_item, items);
    let previous_index = loop_index_backward(index, items.len());
    items[previous_index]
}

fn get_next_row<T: PartialEq + Copy>(current_item: T, items: &[T], columns_count: usize) -> T {
    let index = get_index(current_item, items);
    let row = row_from_index(index, columns_count);
    let column = column_from_index(index, columns_count);
    let rows_count = items.len().div_ceil(columns_count);
    let mut next_index = {
        let next_row = loop_index_forward(row, rows_count);
        // if we hit bottom row, move to the next column
        let next_column = if next_row == 0 {
            loop_index_forward(column, columns_count)
        } else {
            column
        };
        index_from_column_row(next_column, next_row, columns_count)
    };

    if next_index >= items.len() {
        // we hit unpopulated part of bottom row, loop back to first row, next column
        let next_column = loop_index_forward(column, columns_count);
        next_index = index_from_column_row(next_column, 0, columns_count);
    }

    items[next_index]
}

fn get_previous_row<T: PartialEq + Copy>(current_item: T, items: &[T], columns_count: usize) -> T {
    let index = get_index(current_item, items);
    let row = row_from_index(index, columns_count);
    let column = column_from_index(index, columns_count);
    let rows_count = items.len().div_ceil(columns_count);
    let previous_row = loop_index_backward(row, rows_count);
    let mut previous_index = {
        // if we hit top row, move to the previous column
        let previous_column = if previous_row == rows_count - 1 {
            loop_index_backward(column, columns_count)
        } else {
            column
        };
        index_from_column_row(previous_column, previous_row, columns_count)
    };

    if previous_index >= items.len() {
        // we hit unpopulated part of bottom row, move to row above it, previous column
        let previous_column = loop_index_backward(column, columns_count);
        previous_index = index_from_column_row(previous_column, previous_row - 1, columns_count);
    }

    items[previous_index]
}

#[inline(always)]
fn loop_index_forward(index: usize, width: usize) -> usize {
    (index + 1) % width
}

#[inline(always)]
fn loop_index_backward(index: usize, width: usize) -> usize {
    (width + index - 1) % width
}

#[inline(always)]
fn column_from_index(index: usize, columns_count: usize) -> usize {
    index % columns_count
}

#[inline(always)]
fn row_from_index(index: usize, columns_count: usize) -> usize {
    index / columns_count
}

#[inline(always)]
fn index_from_column_row(column: usize, row: usize, columns_count: usize) -> usize {
    row * columns_count + column
}

fn shuffle_vec<T>(vec: &mut [T]) {
    let mut rng = rand::rng();
    vec.shuffle(&mut rng);
}

fn random_element<T>(vec: &[T]) -> &T {
    assert!(!vec.is_empty());
    let random_index = rand::random_range(0..vec.len());
    &vec[random_index]
}

trait WithName {
    fn get_name(self, data: &Data) -> &str;
}

struct State {
    data: Data,
    settings: Settings,
    ui: UI,
    test: Test,
    show_settings: bool,
    exit: bool,
}

struct Settings {
    active_settings_tab: SettingsTab,
    language: TestLanguage,
    ngram: NgramType,
    words_rarity: WordsRarity,
    natural_language_configs: Vec<NaturalLanguageConfig>,
    size: TestSize,
}

struct NaturalLanguageConfig {
    include_letter: IncludeLetter,
    select_letters: HashSet<char>,
    select_letters_priority: Option<char>,
    select_letters_pointer: char,
}

struct UI {
    settings_tabs: Vec<SettingsTab>,
    languages: Vec<TestLanguage>,
    ngrams: Vec<NgramType>,
    words_rarities: Vec<WordsRarity>,
    include_letters: Vec<IncludeLetter>,
    sizes: Vec<TestSize>,
}

struct Test {
    lines: Vec<Vec<String>>,
    goal_chars: Vec<char>,
    char_positions: Vec<Position>,
    input_chars: Vec<char>,
    stage: TestStage,
    start_time: Instant,
    end_time: Instant,
    total_keys_pressed: usize,
    wrong_keys_pressed: usize,
}

#[derive(PartialEq)]
enum TestStage {
    Waiting,
    Running,
    Finished,
}

#[derive(PartialEq, Copy, Clone)]
enum SettingsTab {
    Language,
    NgramType,
    WordsRarity,
    IncludeLetter,
    SelectLetters,
    Size,
}

impl WithName for SettingsTab {
    fn get_name(self, data: &Data) -> &str {
        match self {
            SettingsTab::Language => "language",
            SettingsTab::NgramType => "ngram type",
            SettingsTab::WordsRarity => "words rarity",
            SettingsTab::IncludeLetter => "include letter",
            SettingsTab::SelectLetters => "select letters",
            SettingsTab::Size => "test size",
        }
    }
}

#[derive(PartialEq, Copy, Clone, Debug)]
enum TestLanguage {
    Numbers,
    Symbols,
    Natural(usize)
}

impl WithName for TestLanguage {
    fn get_name(self, data: &Data) -> &str {
        match self {
            TestLanguage::Numbers => "numbers",
            TestLanguage::Symbols => "symbols",
            TestLanguage::Natural(index) => &data.natural_languages[index].name,
        }
    }
}

#[derive(PartialEq, Copy, Clone, Debug)]
enum NgramType {
    Letters,
    Bigrams,
    Trigrams,
    Words,
}

impl WithName for NgramType {
    fn get_name(self, data: &Data) -> &str {
        match self {
            NgramType::Letters => "letters",
            NgramType::Bigrams => "bigrams",
            NgramType::Trigrams => "trigrams",
            NgramType::Words => "words",
        }
    }
}

impl WithName for WordsRarity {
    fn get_name(self, data: &Data) -> &str {
        match self {
            WordsRarity::VeryCommon => "very common",
            WordsRarity::Common => "common",
            WordsRarity::Rare => "rare",
            WordsRarity::VeryRare => "very rare",
        }
    }
}

impl WithName for TestSize {
    fn get_name(self, data: &Data) -> &str {
        match self {
            TestSize::VerySmall => "very small",
            TestSize::Small => "small",
            TestSize::Medium => "medium",
            TestSize::Large => "very large",
        }
    }
}

#[derive(PartialEq, Copy, Clone, Debug)]
enum IncludeLetter {
    All,
    Specific(char),
}

impl IncludeLetter {
    fn get_name(self) -> char {
        match self {
            IncludeLetter::All => '*',
            IncludeLetter::Specific(letter) => letter
        }
    }
}

fn main() {
    setup_logging();

    let data = load_data();
    let settings = get_default_settings(&data);
    let ui = get_default_ui(&data, &settings);
    let test = generate_new_test(&data, &settings);

    let state = State {
        data,
        settings,
        ui,
        test,
        show_settings: false,
        exit: false,
    };

    ratatui::run(|terminal| app(terminal, state));
}

fn load_data() -> Data {
    let data_serialized_compressed = include_bytes!("../../data.bin");
    let data_serialized = miniz_oxide::inflate::decompress_to_vec(data_serialized_compressed).expect("failed to decompress");
    let data: Data = rmp_serde::decode::from_slice(&data_serialized).expect("failed to deserialize");
    data
}

fn get_default_settings(data: &Data) -> Settings {
    let mut natural_language_configs = Vec::with_capacity(data.natural_languages.len());
    for natural_language in &data.natural_languages {
        natural_language_configs.push(get_default_natural_language_config(natural_language));
    }

    Settings {
        active_settings_tab: SettingsTab::Language,
        language: TestLanguage::Natural(0),
        ngram: NgramType::Words,
        words_rarity: WordsRarity::Common,
        natural_language_configs,
        size: TestSize::Small,
    }
}

fn get_default_natural_language_config(natural_language: &NaturalLanguageData) -> NaturalLanguageConfig {
    NaturalLanguageConfig {
        include_letter: IncludeLetter::All,
        select_letters: HashSet::with_capacity(natural_language.alphabet.len()),
        select_letters_priority: None,
        select_letters_pointer: natural_language.alphabet[0],
    }
}

fn get_default_ui(data: &Data, settings: &Settings) -> UI {
    let natural_languages_count = data.natural_languages.len();

    let mut languages = Vec::with_capacity(2 + natural_languages_count);
    languages.push(TestLanguage::Numbers);
    languages.push(TestLanguage::Symbols);
    for i in 0..natural_languages_count {
        languages.push(TestLanguage::Natural(i));
    }

    UI {
        settings_tabs: build_settings_tabs(settings),
        languages,
        ngrams: vec![
            NgramType::Letters,
            NgramType::Bigrams,
            NgramType::Trigrams,
            NgramType::Words
        ],
        words_rarities: vec![
            WordsRarity::VeryCommon,
            WordsRarity::Common,
            WordsRarity::Rare,
            WordsRarity::VeryRare
        ],
        include_letters: build_include_letters(data, settings),
        sizes: vec![
            TestSize::VerySmall,
            TestSize::Small,
            TestSize::Medium,
            TestSize::Large
        ],
    }
}

fn rebuild_ui(ui: &mut UI, data: &Data, settings: &Settings) {
    ui.settings_tabs = build_settings_tabs(settings);
    ui.include_letters = build_include_letters(data, settings);
}

fn build_settings_tabs(settings: &Settings) -> Vec<SettingsTab> {
    match settings.language {
        TestLanguage::Numbers => vec![
            SettingsTab::Language,
            SettingsTab::Size
        ],
        TestLanguage::Symbols => vec![
            SettingsTab::Language,
            SettingsTab::Size
        ],
        TestLanguage::Natural(_) => match settings.ngram {
            NgramType::Letters => vec![
                SettingsTab::Language,
                SettingsTab::NgramType,
                SettingsTab::SelectLetters,
                SettingsTab::Size
            ],
            NgramType::Bigrams => vec![
                SettingsTab::Language,
                SettingsTab::NgramType,
                SettingsTab::Size
            ],
            NgramType::Trigrams => vec![
                SettingsTab::Language,
                SettingsTab::NgramType,
                SettingsTab::Size
            ],
            NgramType::Words => vec![
                SettingsTab::Language,
                SettingsTab::NgramType,
                SettingsTab::WordsRarity,
                SettingsTab::IncludeLetter,
                SettingsTab::Size
            ],
        },
    }
}

fn build_include_letters(data: &Data, settings: &Settings) -> Vec<IncludeLetter> {
    if let TestLanguage::Natural(index) = settings.language {
        let language_data = &data.natural_languages[index];
        let mut result = Vec::with_capacity(language_data.alphabet.len() + 1);

        result.push(IncludeLetter::All);
        for letter in &language_data.alphabet {
            result.push(IncludeLetter::Specific(*letter));
        }

        result
    } else {
        Vec::new()
    }
}

fn setup_logging() {
    // strips logging in release builds
    // don't forget to set spdlog-rs feature "release-level-off"
    if cfg!(debug_assertions) {
        let path = "log.log";
        let file_sink = FileSink::builder().path(path).build_arc().expect("failed to build logger file sink");
        let new_logger = Logger::builder().sink(file_sink).build_arc().expect("failed to build logger");
        spdlog::set_default_logger(new_logger);
    }
}

fn app(terminal: &mut DefaultTerminal, mut state: State) {
    loop {
        update(&mut state);
        if state.exit {
            break
        }
        terminal.draw(|frame| render(frame, &state)).expect("failed to draw frame");
    }
}

fn generate_new_test(data: &Data, settings: &Settings) -> Test {
    let (lines, total_length) = generate_test_lines(data, settings);
    let goal_chars = generate_goal_chars(&lines, total_length);
    let char_positions = generate_char_positions(&lines, total_length);
    let input_chars = generate_input_chars(&lines, total_length);
    let time = Instant::now();
    Test {
        lines,
        goal_chars,
        char_positions,
        input_chars,
        stage: TestStage::Waiting,
        start_time: time,
        end_time: time,
        total_keys_pressed: 0,
        wrong_keys_pressed: 0,
    }
}

fn generate_test_lines(data: &Data, settings: &Settings) -> (Vec<Vec<String>>, usize) {
    let lines_count = data.test_sizes[&settings.size];
    match settings.language {
        TestLanguage::Numbers => RandomWordGenerator::new(&data.numbers, 6).generate_lines(lines_count),
        TestLanguage::Symbols => RandomWordGenerator::new(&data.symbols, 4).generate_lines(lines_count),
        TestLanguage::Natural(index) => {
            let language_data = &data.natural_languages[index];
            let language_config = &settings.natural_language_configs[index];
            match settings.ngram {
                NgramType::Letters => LetterWordGenerator::new(language_config, &language_data.bigrams, &language_data.trigrams).generate_lines(lines_count),
                NgramType::Bigrams => RandomWordSelector::new(&language_data.bigrams).generate_lines(lines_count),
                NgramType::Trigrams => RandomWordSelector::new(&language_data.trigrams).generate_lines(lines_count),
                NgramType::Words => {
                    let words = &language_data.words[&settings.words_rarity];
                    match language_config.include_letter {
                        IncludeLetter::All => RandomWordSelector::new(words).generate_lines(lines_count),
                        IncludeLetter::Specific(letter) => RandomWordSelectorIndexed::new(words, letter).generate_lines(lines_count),
                    }
                }
            }
        }
    }
}

trait TestGenerator {
    fn generate_lines(&mut self, lines_count: usize) -> (Vec<Vec<String>>, usize) {
        let mut line_index = 0;
        let mut line_length = 0;
        let mut total_length = 0;

        let max_line_length = MAX_LINE_LENGTH;
        let mut result_lines = Vec::with_capacity(lines_count);
        let mut current_line = Vec::new();

        loop {
            let next_word = self.generate_next_word();
            let next_word_length = next_word.chars().count() + 1; // put space after every word
            if next_word_length > max_line_length {
                // really long words can screw up algorithm
                break;
            }
            if line_length + next_word_length > max_line_length {
                if line_index >= lines_count - 1 {
                    break;
                }

                result_lines.push(current_line);
                current_line = Vec::new();

                line_length = 0;
                line_index += 1;
            }

            line_length += next_word_length;
            total_length += next_word_length;
            current_line.push(next_word);
        }

        result_lines.push(current_line);

        (result_lines, total_length)
    }

    fn generate_next_word(&mut self) -> String;
}

struct RandomWordGenerator<'a> {
    alphabet: &'a Vec<char>,
    word_length: usize,
    alphabet_indices: Vec<usize>,
    next_index: usize,
}

impl<'a> RandomWordGenerator<'a> {
    fn new(alphabet: &'a Vec<char>, word_length: usize) -> RandomWordGenerator<'a> {
        assert!(!alphabet.is_empty());
        let mut alphabet_indices: Vec<usize> = (0..alphabet.len()).collect();
        shuffle_vec(&mut alphabet_indices);
        RandomWordGenerator {
            alphabet,
            word_length,
            alphabet_indices,
            next_index: 0,
        }
    }

    fn get_next_word(&mut self) -> String {
        let mut result = String::with_capacity(self.word_length);
        let mut previous_letter_option: Option<char> = None;

        while result.len() < self.word_length {
            let next_letter = self.get_next_letter();
            if let Some(previous_letter) = previous_letter_option && next_letter == previous_letter {
                continue;
            }

            result.push(next_letter);
            previous_letter_option = Some(next_letter);
        }

        result
    }

    fn get_next_letter(&mut self) -> char {
        if self.next_index >= self.alphabet_indices.len() {
            shuffle_vec(&mut self.alphabet_indices);
            self.next_index = 0;
        }

        let next_letter = self.alphabet[self.alphabet_indices[self.next_index]];
        self.next_index += 1;
        next_letter
    }
}

impl<'a> TestGenerator for RandomWordGenerator<'a> {
    fn generate_next_word(&mut self) -> String {
        self.get_next_word()
    }
}

struct RandomWordSelector<'a> {
    words: &'a Vec<String>,
}

impl<'a> RandomWordSelector<'a> {
    fn new(words: &'a Vec<String>) -> RandomWordSelector<'a> {
        RandomWordSelector {
            words
        }
    }

    fn get_next_word(&self) -> String {
        random_element(self.words).clone()
    }
}

impl<'a> TestGenerator for RandomWordSelector<'a> {
    fn generate_next_word(&mut self) -> String {
        self.get_next_word()
    }
}

struct RandomWordSelectorIndexed<'a> {
    all_words: &'a Vec<String>,
    indexes: Vec<usize>,
}

impl<'a> RandomWordSelectorIndexed<'a> {
    fn new(all_words: &'a Vec<String>, target_letter: char) -> RandomWordSelectorIndexed<'a> {
        let mut indexes = Vec::new();

        // get words that contain target letter
        for (word_index, word) in all_words.iter().enumerate() {
            for letter in word.chars() {
                if letter == target_letter {
                    indexes.push(word_index);
                    break;
                }
            }
        }

        RandomWordSelectorIndexed {
            all_words,
            indexes,
        }
    }

    fn get_next_word(&self) -> String {
        if self.indexes.is_empty() {
            "no words".to_string()
        } else {
            self.all_words[*random_element(&self.indexes)].clone()
        }
    }
}

impl<'a> TestGenerator for RandomWordSelectorIndexed<'a> {
    fn generate_next_word(&mut self) -> String {
        self.get_next_word()
    }
}

struct LetterWordGenerator {
    available_word_tokens_per_letter: HashMap<char, LetterTokens>,
    available_word_tokens: Vec<String>,
    available_word_tokens_copy: Vec<String>,
    target_letter: Option<char>,
}

struct LetterTokens {
    total_tokens_count: usize,
    unique_tokens: Vec<String>,
}

impl LetterTokens {
    fn new() -> LetterTokens {
        LetterTokens {
            total_tokens_count: 0,
            unique_tokens: Vec::new(),
        }
    }

    fn push_unique_token(&mut self, token: String) {
        self.unique_tokens.push(token);
        self.total_tokens_count += 1;
    }

    fn push_shared_token(&mut self) {
        self.total_tokens_count += 1;
    }

    fn fill_tokens(&mut self, letter: char, target_tokens_count: usize, target_array: &mut Vec<String>) {
        target_array.extend_from_slice(&self.unique_tokens);
        let diff = target_tokens_count - self.total_tokens_count;
        if diff > 0 {
            // make rare letters more common by adding letters themselves as tokens
            // our goal is spread letters evenly across the test
            let letter_string = letter.to_string();
            for _ in 0..diff {
                target_array.push(letter_string.clone());
            }
        }
    }
}

impl LetterWordGenerator {
    fn new(language_config: &NaturalLanguageConfig, bigrams: &[String], trigrams: &[String]) -> LetterWordGenerator {
        let letters = &language_config.select_letters;
        if letters.is_empty() {
            return LetterWordGenerator {
                available_word_tokens_per_letter: HashMap::new(),
                available_word_tokens: Vec::new(),
                available_word_tokens_copy: Vec::new(),
                target_letter: language_config.select_letters_priority,
            };
        }

        let mut available_word_tokens_per_letter = HashMap::with_capacity(letters.len());

        for letter in letters {
            available_word_tokens_per_letter.insert(*letter, LetterTokens::new());
        }

        // add letters themselves as tokens because rare ones often don't have bigrams/trigrams
        for letter in letters {
            available_word_tokens_per_letter.get_mut(letter).unwrap().push_unique_token(letter.to_string());
        }

        // get all available bigrams
        for bigram in bigrams {
            let mut bigram_chars = bigram.chars();
            let letter_0 = bigram_chars.next().expect("no left char in bigram?");
            let letter_1 = bigram_chars.next().expect("no right char in bigram?");

            // no need for repetition
            if letter_0 == letter_1 {
                continue;
            }

            // check if bigram can be made from selected letters
            let is_available =
                available_word_tokens_per_letter.contains_key(&letter_0) &&
                available_word_tokens_per_letter.contains_key(&letter_1);

            if is_available {
                available_word_tokens_per_letter.get_mut(&letter_0).unwrap().push_unique_token(bigram.clone());
                available_word_tokens_per_letter.get_mut(&letter_1).unwrap().push_shared_token();
            }
        }

        // get all available trigrams
        for trigram in trigrams {
            let mut trigram_chars = trigram.chars();
            let letter_0 = trigram_chars.next().expect("no left char in trigram?");
            let letter_1 = trigram_chars.next().expect("no middle char in trigram?");
            let letter_2 = trigram_chars.next().expect("no right char in trigram?");

            // no need for repetition
            if letter_0 == letter_1 || letter_1 == letter_2 {
                continue
            }

            // check if bigram can be made from selected letters
            let is_available =
                available_word_tokens_per_letter.contains_key(&letter_0) &&
                available_word_tokens_per_letter.contains_key(&letter_1) &&
                available_word_tokens_per_letter.contains_key(&letter_2);

            if is_available {
                available_word_tokens_per_letter.get_mut(&letter_0).unwrap().push_unique_token(trigram.clone());
                available_word_tokens_per_letter.get_mut(&letter_1).unwrap().push_shared_token();
                available_word_tokens_per_letter.get_mut(&letter_2).unwrap().push_shared_token();
            }
        }

        // calculate how many times the most frequent token appears,
        // we will use this to increase other tokens count
        let mut max_tokens_count = 0;
        for (letter, letter_tokens) in &available_word_tokens_per_letter {
            if letter_tokens.total_tokens_count > max_tokens_count {
                max_tokens_count = letter_tokens.total_tokens_count;
            }
        }
        assert!(max_tokens_count != 0);

        // collect all available word tokens
        let mut available_word_tokens = Vec::new();
        for (letter, letter_tokens) in &mut available_word_tokens_per_letter {
            letter_tokens.fill_tokens(*letter, max_tokens_count, &mut available_word_tokens);
        }

        let available_word_tokens_copy = Vec::with_capacity(available_word_tokens.len());
        LetterWordGenerator {
            available_word_tokens_per_letter,
            available_word_tokens,
            available_word_tokens_copy,
            target_letter: language_config.select_letters_priority,
        }
    }

    fn get_next_word(&mut self) -> String {
        if self.available_word_tokens.is_empty() {
            return "select letters".to_string();
        }

        let word_length = 3;

        // target letter token can be added afterward
        let mut word_builder = Vec::with_capacity(word_length + 1);
        for _ in 0..word_length {
            if self.available_word_tokens_copy.is_empty() {
                self.available_word_tokens_copy.extend_from_slice(&self.available_word_tokens);
                shuffle_vec(&mut self.available_word_tokens_copy);
            }

            let next_token = self.available_word_tokens_copy.pop().expect("no tokens");
            word_builder.push(next_token);
        }

        if let Some(target_letter) = self.target_letter {
            let mut has_target_letter = false;

            for token in &word_builder {
                for letter in token.chars() {
                    if letter == target_letter {
                        has_target_letter = true;
                        break;
                    }
                }
            }

            if !has_target_letter {
                let tokens_with_target_letter = &self.available_word_tokens_per_letter[&target_letter].unique_tokens;
                let next_token = random_element(tokens_with_target_letter);
                word_builder.push(next_token.clone());
            }
        }

        shuffle_vec(&mut word_builder);
        word_builder.concat()
    }
}

impl TestGenerator for LetterWordGenerator {
    fn generate_next_word(&mut self) -> String {
        self.get_next_word()
    }
}

fn generate_goal_chars(lines: &Vec<Vec<String>>, total_length: usize) -> Vec<char> {
    let mut goal_chars = Vec::with_capacity(total_length);
    for line in lines {
        for word in line {
            for char in word.chars() {
                goal_chars.push(char);
            }
            goal_chars.push(' ');
        }
    }
    goal_chars
}

fn generate_input_chars(lines: &Vec<Vec<String>>, total_length: usize) -> Vec<char>{
    Vec::with_capacity(total_length)
}

fn generate_char_positions(lines: &Vec<Vec<String>>, total_length: usize) -> Vec<Position> {
    let mut char_positions = Vec::with_capacity(total_length);
    for (y, line) in lines.iter().enumerate() {
        let mut x = 0;
        for word in line {
            for char in word.chars() {
                char_positions.push(Position::new(x, y as u16));
                x += 1;
            }
            {
                char_positions.push(Position::new(x, y as u16));
                x += 1;
            }
        }
    }
    char_positions
}

fn update(state: &mut State) {
    match event::read().expect("failed to read event") {
        Event::Key(key_event) if key_event.kind.is_press() => key_input(key_event, state),
        _ => {}
    }
}

fn key_input(key_event: KeyEvent, state: &mut State) {
    info!("input code: {}, modifiers: {}", key_event.code, key_event.modifiers);

    if key_event.modifiers.contains(KeyModifiers::CONTROL) && key_event.code.is_char('c') {
        state.exit = true;
        return;
    };

    if !state.show_settings && key_event.code == KeyCode::Enter {
        state.show_settings = true;
        return;
    }

    match key_event.code {
        KeyCode::Esc => {
            if state.show_settings {
                state.show_settings = false;
                return;
            }
        }
        KeyCode::Enter => if state.show_settings {
            if state.settings.active_settings_tab == SettingsTab::SelectLetters {
                if let TestLanguage::Natural(index) = state.settings.language {
                    let language_config = &mut state.settings.natural_language_configs[index];

                    // cycle pointer letter state:
                    if !language_config.select_letters.contains(&language_config.select_letters_pointer) {
                        // not included -> priority
                        language_config.select_letters.insert(language_config.select_letters_pointer);
                        language_config.select_letters_priority = Some(language_config.select_letters_pointer);
                    }  else if let Some(priority) = language_config.select_letters_priority && language_config.select_letters_pointer == priority {
                        // priority -> included
                        language_config.select_letters_priority = None;
                    } else {
                        // included -> not included
                        language_config.select_letters.remove(&language_config.select_letters_pointer);
                    }

                    rebuild_ui(&mut state.ui, &state.data, &state.settings);
                    start_new_test(state);
                }
            } else {
                state.show_settings = !state.show_settings;
            }
            return;
        },
        KeyCode::Tab => {
            state.settings.active_settings_tab = get_next(state.settings.active_settings_tab, &state.ui.settings_tabs);
            state.show_settings = true;
            return;
        },
        KeyCode::BackTab => {
            state.settings.active_settings_tab = get_previous(state.settings.active_settings_tab, &state.ui.settings_tabs);
            state.show_settings = true;
            return;
        },
        KeyCode::Down => if state.show_settings {
            match state.settings.active_settings_tab {
                SettingsTab::Language => state.settings.language = get_next(state.settings.language, &state.ui.languages),
                SettingsTab::NgramType => state.settings.ngram = get_next(state.settings.ngram, &state.ui.ngrams),
                SettingsTab::WordsRarity => state.settings.words_rarity = get_next(state.settings.words_rarity, &state.ui.words_rarities),
                SettingsTab::IncludeLetter => {
                    if let TestLanguage::Natural(index) = state.settings.language {
                        let language_config = &mut state.settings.natural_language_configs[index];
                        language_config.include_letter = get_next_row(language_config.include_letter, &state.ui.include_letters, INCLUDE_LETTER_UI_MATRIX_WIDTH);
                    }
                }
                SettingsTab::SelectLetters => {
                    if let TestLanguage::Natural(index) = state.settings.language {
                        let language_data = &state.data.natural_languages[index];
                        let language_config = &mut state.settings.natural_language_configs[index];
                        language_config.select_letters_pointer = get_next_row(language_config.select_letters_pointer, &language_data.alphabet, INCLUDE_LETTER_UI_MATRIX_WIDTH);
                    }
                }
                SettingsTab::Size => state.settings.size = get_next(state.settings.size, &state.ui.sizes),
            };
            // TODO full ui rebuild is not required in some cases
            rebuild_ui(&mut state.ui, &state.data, &state.settings);
            start_new_test(state);
            return;
        },
        KeyCode::Up => if state.show_settings {
            match state.settings.active_settings_tab {
                SettingsTab::Language => state.settings.language = get_previous(state.settings.language, &state.ui.languages),
                SettingsTab::NgramType => state.settings.ngram = get_previous(state.settings.ngram, &state.ui.ngrams),
                SettingsTab::WordsRarity => state.settings.words_rarity = get_previous(state.settings.words_rarity, &state.ui.words_rarities),
                SettingsTab::IncludeLetter => {
                    if let TestLanguage::Natural(index) = state.settings.language {
                        let language_config = &mut state.settings.natural_language_configs[index];
                        language_config.include_letter = get_previous_row(language_config.include_letter, &state.ui.include_letters, INCLUDE_LETTER_UI_MATRIX_WIDTH);
                    }
                }
                SettingsTab::SelectLetters => {
                    if let TestLanguage::Natural(index) = state.settings.language {
                        let language_data = &state.data.natural_languages[index];
                        let language_config = &mut state.settings.natural_language_configs[index];
                        language_config.select_letters_pointer = get_previous_row(language_config.select_letters_pointer, &language_data.alphabet, INCLUDE_LETTER_UI_MATRIX_WIDTH);
                    }
                }
                SettingsTab::Size => state.settings.size = get_previous(state.settings.size, &state.ui.sizes),
            };
            rebuild_ui(&mut state.ui, &state.data, &state.settings);
            start_new_test(state);
            return;
        },
        KeyCode::Right => if state.show_settings {
            match state.settings.active_settings_tab {
                SettingsTab::IncludeLetter => {
                    if let TestLanguage::Natural(index) = state.settings.language {
                        let language_config = &mut state.settings.natural_language_configs[index];
                        language_config.include_letter = get_next(language_config.include_letter, &state.ui.include_letters);

                        rebuild_ui(&mut state.ui, &state.data, &state.settings);
                        start_new_test(state);
                    }
                },
                SettingsTab::SelectLetters => {
                    if let TestLanguage::Natural(index) = state.settings.language {
                        let language_data = &state.data.natural_languages[index];
                        let language_config = &mut state.settings.natural_language_configs[index];
                        language_config.select_letters_pointer = get_next(language_config.select_letters_pointer, &language_data.alphabet);
                    }
                }
                _ => {}
            };
            return;
        },
        KeyCode::Left => if state.show_settings {
            match state.settings.active_settings_tab {
                SettingsTab::IncludeLetter => {
                    if let TestLanguage::Natural(index) = state.settings.language {
                        let language_config = &mut state.settings.natural_language_configs[index];
                        language_config.include_letter = get_previous(language_config.include_letter, &state.ui.include_letters);

                        rebuild_ui(&mut state.ui, &state.data, &state.settings);
                        start_new_test(state);
                    }
                },
                SettingsTab::SelectLetters => {
                    if let TestLanguage::Natural(index) = state.settings.language {
                        let language_data = &state.data.natural_languages[index];
                        let language_config = &mut state.settings.natural_language_configs[index];
                        language_config.select_letters_pointer = get_previous(language_config.select_letters_pointer, &language_data.alphabet);
                    }
                }
                _ => {}
            };
            return;
        },
        _ => {}
    }

    if state.show_settings {
        return;
    }

    match state.test.stage {
        TestStage::Waiting => match key_event.code {
            KeyCode::Esc => start_new_test(state),
            KeyCode::Char(key_char) => {
                push_new_char(&mut state.test, key_char);
                state.test.start_time = Instant::now();
                state.test.stage = TestStage::Running;
            },
            _ => {}
        }
        TestStage::Running => match key_event.code {
            KeyCode::Esc => reset_current_test(&mut state.test),
            KeyCode::Backspace => {
                if state.test.input_chars.len() > 1 {
                    state.test.input_chars.pop();
                    // should we count backspaces in wpm/cpm? debatable
                    state.test.total_keys_pressed += 1;
                } else {
                    reset_current_test(&mut state.test);
                }
            },
            KeyCode::Char(key_char) => {
                push_new_char(&mut state.test, key_char);
                if state.test.input_chars.len() >= state.test.goal_chars.len() - 1 {
                    state.test.end_time = Instant::now();
                    state.test.stage = TestStage::Finished;
                }
            },
            _ => {}
        }
        TestStage::Finished => match key_event.code {
            KeyCode::Esc => reset_current_test(&mut state.test),
            KeyCode::Char(' ') => start_new_test(state),
            _ => {}
        }
    }
}

fn push_new_char(test: &mut Test, new_char: char) {
    test.input_chars.push(new_char);
    test.total_keys_pressed += 1;

    let new_char_index = test.input_chars.len() - 1;
    let goal_char = test.goal_chars[new_char_index];
    if new_char != goal_char {
        test.wrong_keys_pressed += 1;
    }
}

fn start_new_test(state: &mut State) {
    state.test = generate_new_test(&state.data, &state.settings);
}

fn reset_current_test(test: &mut Test) {
    test.input_chars.clear();
    test.stage = TestStage::Waiting;
    test.total_keys_pressed = 0;
    test.wrong_keys_pressed = 0;
}

fn render(frame: &mut Frame, state: &State) {
    let test = &state.test;
    let frame_area = frame.area();

    // draw background border
    let title_line = Line::from("drochetype");
    let test_stage_line = match test.stage {
        TestStage::Waiting => Line::from("waiting"),
        TestStage::Running => Line::from("running").fg(Color::Green),
        TestStage::Finished => Line::from("finished").fg(Color::Yellow),
    };
    let block = Block::default()
        .title_top(title_line.centered())
        .title_bottom(test_stage_line)
        .borders(Borders::ALL);

    frame.render_widget(block, frame_area);

    // draw main text
    // TODO if stuff does not fit with max_text_height, then use text_height
    let text = generate_text_from_test(test);
    let text_height = text.height();
    let max_text_height = *state.data.test_sizes.values().max().expect("no items in test_sizes array?");
    let text_area = Rect::new(
        get_center(frame_area.width, MAX_LINE_LENGTH as u16),
        get_center(frame_area.height, max_text_height as u16),
        MAX_LINE_LENGTH as u16,
        max_text_height as u16
    );
    frame.render_widget(text, text_area);

    // draw cursor
    if !state.show_settings {
        let cursor_position_index = test.input_chars.len();
        let cursor_position_local = test.char_positions[cursor_position_index];
        frame.set_cursor_position(cursor_position_local + text_area.as_position().into());
    }

    // draw settings tabs
    let separator = " • ";
    let active_settings_tab_index = get_index(state.settings.active_settings_tab, &state.ui.settings_tabs);
    let active_settings_tab_style = Style::default().add_modifier(Modifier::UNDERLINED);
    let mut tab_names = Vec::with_capacity(state.ui.settings_tabs.len() * 2 + 1); // reserve space for tab names and separators

    tab_names.push(Span::from(separator));
    for settings_tab in &state.ui.settings_tabs {
        let settings_tab_name = settings_tab.get_name(&state.data);
        if *settings_tab == state.settings.active_settings_tab {
            tab_names.push(Span::styled(settings_tab_name, active_settings_tab_style));
        } else {
            tab_names.push(Span::from(settings_tab_name));
        }
        tab_names.push(Span::from(separator));
    }

    let active_tab_name_x_local = get_tab_name_x(active_settings_tab_index, &tab_names);
    let tabs = Line::from(tab_names);
    let tabs_width = tabs.width() as u16;
    let tabs_area = Rect::new(get_center(frame_area.width, tabs_width), text_area.y - 2, tabs_width, 1);
    let active_tab_name_x = active_tab_name_x_local + tabs_area.x - 2;
    frame.render_widget(tabs, tabs_area);

    // draw result line
    if test.stage == TestStage::Finished {
        let elapsed_time = test.end_time.duration_since(test.start_time);
        let elapsed_seconds = elapsed_time.as_secs();
        let time_string = format!("{0:02}:{1:02}", elapsed_seconds / 60, elapsed_seconds % 60);
        let accuracy = (test.total_keys_pressed - test.wrong_keys_pressed) as f64 / test.total_keys_pressed as f64 * 100.0;
        let accuracy_string = format!("{}%", accuracy.floor());
        let cpm = 60.0 * test.total_keys_pressed as f64 / elapsed_time.as_secs_f64();
        let cpm_string = cpm.floor().to_string();
        let wpm = cpm / 5.0;
        let wpm_string = wpm.floor().to_string();
        let result_line = Line::from(vec![
            Span::from("acc: "),
            Span::from(accuracy_string).fg(Color::Yellow),
            Span::from(" wpm: "),
            Span::from(wpm_string).fg(Color::Yellow),
            Span::from(" cpm: "),
            Span::from(cpm_string).fg(Color::Yellow),
            Span::from(" time: "),
            Span::from(time_string).fg(Color::Yellow),
        ]);
        let result_line_area = Rect::new(text_area.x, text_area.y + text_height as u16 + 1, frame_area.width, 1);
        frame.render_widget(result_line, result_line_area);
    };

    // draw settings options
    if state.show_settings {
        let text = get_settings_options(state);
        let title_name = state.settings.active_settings_tab.get_name(&state.data);
        let title = Line::styled(title_name, active_settings_tab_style);
        let text_area_width = title.width() + 4;
        let text_area_height = text.height() + 2;
        let text_area = Rect::new(active_tab_name_x, tabs_area.y, text_area_width as u16, text_area_height as u16);
        let paragraph = Paragraph::new(text).block(Block::default().borders(Borders::ALL).title_top(title.centered()));
        frame.render_widget(Clear, text_area);
        frame.render_widget(paragraph, text_area);
    }
}

fn get_center(parent_size: u16, child_size: u16) -> u16 {
    ((parent_size - child_size) as f64 / 2.0).floor() as u16
}

fn get_tab_name_x(tab_index: usize, tab_names: &Vec<Span>) -> u16 {
    let real_index = tab_index * 2 + 1;
    let mut x: usize = 0;
    for (i, tab_name) in tab_names.iter().enumerate() {
        if i == real_index {
            break;
        }
        x += tab_name.width();
    }
    x as u16
}

fn get_settings_options<'a>(state: &'a State) -> Text<'a> {
    match state.settings.active_settings_tab {
        SettingsTab::Language => {
            get_settings_options_text(&state.ui.languages, state.settings.language, &state.data)
        },
        SettingsTab::NgramType => {
            get_settings_options_text(&state.ui.ngrams, state.settings.ngram, &state.data)
        },
        SettingsTab::WordsRarity => {
            get_settings_options_text(&state.ui.words_rarities, state.settings.words_rarity, &state.data)
        },
        SettingsTab::IncludeLetter => {
            if let TestLanguage::Natural(index) = state.settings.language {
                let language_config = &state.settings.natural_language_configs[index];
                generate_include_letter_ui_matrix(&state.ui.include_letters, language_config.include_letter)
            } else {
                panic!("WTF")
            }
        },
        SettingsTab::SelectLetters => {
            if let TestLanguage::Natural(index) = state.settings.language {
                let language_data = &state.data.natural_languages[index];
                let language_config = &state.settings.natural_language_configs[index];
                generate_select_letters_ui_matrix(&language_data.alphabet, language_config)
            } else {
                panic!("WTF")
            }
        },
        SettingsTab::Size => {
            get_settings_options_text(&state.ui.sizes, state.settings.size, &state.data)
        },
    }
}

fn get_settings_options_text<'a, T: WithName + Copy + PartialEq>(options: &[T], active_option: T, data: &'a Data) -> Text<'a> {
    let mut lines = Vec::with_capacity(options.len());
    for option in options {
        let name = option.get_name(data);
        if *option == active_option {
            lines.push(Line::styled(name, Style::default().fg(Color::Yellow)).centered());
        } else {
            lines.push(Line::styled(name, Style::default()).centered());
        }
    }
    Text::from(lines)
}

fn generate_include_letter_ui_matrix<'a>(include_letters: &[IncludeLetter], include_letter: IncludeLetter) -> Text<'a>{
    let include_letter_index = get_index(include_letter, include_letters);
    let lines_count = include_letters.len().div_ceil(INCLUDE_LETTER_UI_MATRIX_WIDTH);
    let mut lines = Vec::with_capacity(lines_count);
    let mut letter_index = 0;
    for _ in 0..lines_count {
        let mut spans = Vec::with_capacity(INCLUDE_LETTER_UI_MATRIX_WIDTH * 2 - 1);
        for i in 0..INCLUDE_LETTER_UI_MATRIX_WIDTH {
            let letter_name = if letter_index < include_letters.len() {
                include_letters[letter_index].get_name()
            } else {
                ' '
            };

            let letter_style = if letter_index == include_letter_index {
                Style::default().fg(Color::Yellow)
            } else {
                Style::default()
            };

            spans.push(Span::styled(letter_name.to_string(), letter_style));
            letter_index += 1;

            if i < INCLUDE_LETTER_UI_MATRIX_WIDTH - 1 {
                spans.push(Span::from(' '.to_string()));
            }
        }

        let line = Line::from(spans).centered();
        lines.push(line);
    }

    Text::from(lines)
}

fn generate_select_letters_ui_matrix<'a>(alphabet: &[char], language_config: &NaturalLanguageConfig) -> Text<'a> {
    let select_letters_pointer_index = get_index(language_config.select_letters_pointer, alphabet);
    let lines_count = alphabet.len().div_ceil(INCLUDE_LETTER_UI_MATRIX_WIDTH);
    let mut lines = Vec::with_capacity(lines_count);
    let mut letter_index = 0;
    for _ in 0..lines_count {
        let mut spans = Vec::with_capacity(INCLUDE_LETTER_UI_MATRIX_WIDTH * 2 - 1);
        for i in 0..INCLUDE_LETTER_UI_MATRIX_WIDTH {
            let (letter_name, letter_color) = if letter_index < alphabet.len() {
                let letter = alphabet[letter_index];
                let color = if !language_config.select_letters.contains(&letter) {
                    Color::Reset
                } else if let Some(priority) = language_config.select_letters_priority && letter == priority {
                    Color::Yellow
                } else {
                    Color::Green
                };
                (letter, color)
            } else {
                (' ', Color::Reset)
            };

            // TODO replace with cursor
            let letter_modifier = if letter_index == select_letters_pointer_index {
                Modifier::UNDERLINED
            } else {
                Modifier::empty()
            };

            let letter_style = Style::default().fg(letter_color).add_modifier(letter_modifier);

            spans.push(Span::styled(letter_name.to_string(), letter_style));
            letter_index += 1;

            if i < INCLUDE_LETTER_UI_MATRIX_WIDTH - 1 {
                spans.push(Span::from(' '.to_string()));
            }
        }

        let line = Line::from(spans).centered();
        lines.push(line);
    }

    Text::from(lines)
}

fn generate_text_from_test<'a>(test: &Test) -> Text<'a> {
    let mut lines = Vec::with_capacity(test.lines.len());

    let mut span_index = 0;
    for test_line in &test.lines {
        let mut line_spans = Vec::with_capacity(MAX_LINE_LENGTH);
        for test_word in test_line {
            for char in test_word.chars() {
                let span = get_char_span(span_index, &test.goal_chars, &test.input_chars);
                line_spans.push(span);
                span_index += 1;
            }
            {
                let span = get_char_span(span_index, &test.goal_chars, &test.input_chars);
                line_spans.push(span);
                span_index += 1;
            }
        }
        let line = Line::from(line_spans);
        lines.push(line);
    }

    Text::from(lines)
}

fn get_char_span<'a>(char_index: usize, goal_chars: &[char], input_chars: &[char]) -> Span<'a> {
    if char_index >= input_chars.len() {
        let char = goal_chars[char_index];
        return Span::from(char.to_string());
    }
    if input_chars[char_index] == goal_chars[char_index] {
        let char = goal_chars[char_index];
        let style = Style::default().fg(Color::Green);
        return Span::styled(char.to_string(), style);
    } else {
        let mut char = input_chars[char_index];
        if char == ' ' {
            char = '_';
        }
        let style = Style::default().fg(Color::Red);
        return Span::styled(char.to_string(), style);
    }
}
