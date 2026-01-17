use anyhow::Result;
use serde::{
    Deserialize, Serialize,
    de::DeserializeOwned,
};
use std::{
    collections::{HashMap, HashSet},
    path::Path,
    time::{Instant, Duration},
};
use spdlog::{prelude::*, sink::FileSink};
use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use rand::prelude::SliceRandom;
use ratatui::{
    buffer::Buffer,
    layout::{Rect, Constraint, Position, Size, Offset},
    style::{Stylize, Color, Style, Modifier},
    symbols,
    symbols::border,
    text::{Span, Line, Text},
    widgets::{Block, Paragraph, Widget, Borders, Tabs, Clear},
    DefaultTerminal, Frame,
};

const MAX_LINE_LENGTH: usize = 45; // TODO add different widths: narrow, medium, wide

struct TestSettings {
    active_settings_tab: SettingsTab,
    language: TestLanguage,
    ngram: NgramType,
    words_rarity: WordsRarity,
    natural_language_configs: HashMap<usize, TypingConfigNaturalLanguage>,
    size: TestSize,
}

struct TestUI {
    settings_tabs: Vec<SettingsTab>,
    languages: Vec<TestLanguage>,
    ngrams: Vec<NgramType>,
    words_rarities: Vec<WordsRarity>,
    sizes: Vec<TestSize>,
}

fn get_index<T: PartialEq + Copy>(current_item: T, items: &[T]) -> usize {
    items.iter().position(|v| *v == current_item).expect("current item is not in items vec")
}

fn get_next<T: PartialEq + Copy>(current_item: T, items: &[T]) -> T {
    let index = get_index(current_item, items);
    let next_index = (index + 1) % items.len();
    items[next_index]
}

fn get_previous<T: PartialEq + Copy>(current_item: T, items: &[T]) -> T {
    let index = get_index(current_item, items);
    let previous_index = (items.len() + index - 1) % items.len();
    items[previous_index]
}

fn build_settings_tabs(test_settings: &TestSettings) -> Vec<SettingsTab> {
    match test_settings.language {
        TestLanguage::Numbers => vec![
            SettingsTab::Language,
            SettingsTab::Size
        ],
        TestLanguage::Symbols => vec![
            SettingsTab::Language,
            SettingsTab::Size
        ],
        TestLanguage::Natural(_) => match test_settings.ngram {
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

trait WithName {
    fn get_name(self, typing_data: &TypingData) -> String;
}

#[derive(PartialEq, Copy, Clone, Debug)]
enum TestLanguage {
    Numbers,
    Symbols,
    Natural(usize)
}

impl WithName for TestLanguage {
    fn get_name(self, typing_data: &TypingData) -> String {
        match self {
            TestLanguage::Numbers => "numbers".to_string(),
            TestLanguage::Symbols => "symbols".to_string(),
            TestLanguage::Natural(index) => typing_data.natural_languages[index].name.clone(),
        }
    }
}

#[derive(PartialEq, Copy, Clone, Debug)]
#[repr(usize)]
enum NgramType {
    Letters,
    Bigrams,
    Trigrams,
    Words,
}

impl WithName for NgramType {
    fn get_name(self, typing_data: &TypingData) -> String {
        match self {
            NgramType::Letters => "letters".to_string(),
            NgramType::Bigrams => "bigrams".to_string(),
            NgramType::Trigrams => "trigrams".to_string(),
            NgramType::Words => "words".to_string(),
        }
    }
}

#[derive(Hash, Eq, PartialEq, Copy, Clone, Debug)]
#[repr(usize)]
enum WordsRarity {
    VeryCommon,
    Common,
    Rare,
    VeryRare,
}

impl WithName for WordsRarity {
    fn get_name(self, typing_data: &TypingData) -> String {
        match self {
            WordsRarity::VeryCommon => "very common".to_string(),
            WordsRarity::Common => "common".to_string(),
            WordsRarity::Rare => "rare".to_string(),
            WordsRarity::VeryRare => "very rare".to_string(),
        }
    }
}

#[derive(Hash, Eq, PartialEq, Copy, Clone, Debug)]
#[repr(usize)]
enum TestSize {
    VerySmall,
    Small,
    Medium,
    Large,
}

impl WithName for TestSize {
    fn get_name(self, typing_data: &TypingData) -> String {
        match self {
            TestSize::VerySmall => "very small".to_string(),
            TestSize::Small => "small".to_string(),
            TestSize::Medium => "medium".to_string(),
            TestSize::Large => "very large".to_string(),
        }
    }
}

struct TypingConfigNaturalLanguage {
    words_include_letter: usize,
    learn_letters: HashSet<usize>,
    learn_letters_priority: usize,
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

struct TypingData {
    numbers: Vec<char>,
    symbols: Vec<char>,
    natural_languages: Vec<TypingDataNaturalLanguage>,
    test_sizes: HashMap<TestSize, usize>,
}

struct TypingDataNaturalLanguage {
    name: String,
    alphabet: Vec<char>,
    alphabet_dict: HashMap<char, usize>,
    bigrams: Vec<String>,
    trigrams: Vec<String>,
    words: HashMap<WordsRarity, NaturalLanguageWords>,
}

struct NaturalLanguageWords {
    all_words: Vec<String>,
    per_letter: HashMap<char, Vec<usize>>,
}

struct Localization {
    languages: Vec<String>,
    ngrams: Vec<String>,
    words_rarities: Vec<String>,
    sizes: Vec<String>,
}

struct State {
    typing_data: TypingData,
    test_data: TestData,
    test_state: TestState,
    test_start_time: Instant,
    test_end_time: Instant,
    total_keys_pressed: usize,
    wrong_keys_pressed: usize,
    show_settings: bool,
    test_settings: TestSettings,
    test_ui: TestUI,
    exit: bool,
}

#[derive(PartialEq)]
enum TestState {
    Waiting,
    Running,
    Finished,
}

struct TestData {
    lines: Vec<Vec<String>>,
    goal_chars: Vec<char>,
    input_chars: Vec<char>,
    char_positions: Vec<Position>,
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
    fn get_name(self, typing_data: &TypingData) -> String {
        match self {
            SettingsTab::Language => "language".to_string(),
            SettingsTab::NgramType => "ngram type".to_string(),
            SettingsTab::WordsRarity => "words rarity".to_string(),
            SettingsTab::IncludeLetter => "include letter".to_string(),
            SettingsTab::SelectLetters => "select letters".to_string(),
            SettingsTab::Size => "test size".to_string(),
        }
    }
}

fn main() {
    setup_logging();

    let typing_data = load_typing_data();
    let test_settings = get_default_test_settings(&typing_data);
    let test_data = generate_test_data(&typing_data, &test_settings);
    let test_ui = get_default_ui(&typing_data, &test_settings);
    let time = Instant::now();
    let state = State {
        typing_data,
        test_data,
        test_state: TestState::Waiting,
        test_start_time: time,
        test_end_time: time,
        total_keys_pressed: 0,
        wrong_keys_pressed: 0,
        show_settings: false,
        test_settings,
        test_ui,
        exit: false,
    };

    ratatui::run(|terminal| app(terminal, state));
}

fn get_default_test_settings(typing_data: &TypingData) -> TestSettings {
    let natural_languages_count = typing_data.natural_languages.len();
    TestSettings {
        active_settings_tab: SettingsTab::Language,
        language: TestLanguage::Natural(0),
        ngram: NgramType::Words,
        words_rarity: WordsRarity::Common,
        natural_language_configs: HashMap::with_capacity(natural_languages_count),
        size: TestSize::Small,
    }
}

fn get_default_ui(typing_data: &TypingData, test_settings: &TestSettings) -> TestUI {
    let natural_languages_count = typing_data.natural_languages.len();

    let mut languages = Vec::with_capacity(2 + natural_languages_count);
    languages.push(TestLanguage::Numbers);
    languages.push(TestLanguage::Symbols);
    for i in 0..natural_languages_count {
        languages.push(TestLanguage::Natural(i));
    }

    TestUI {
        settings_tabs: build_settings_tabs(test_settings),
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
        sizes: vec![
            TestSize::VerySmall,
            TestSize::Small,
            TestSize::Medium,
            TestSize::Large
        ],
    }
}

fn rebuild_ui(ui: &mut TestUI, typing_data: &TypingData, test_settings: &TestSettings) {
    ui.settings_tabs = build_settings_tabs(test_settings)
}

fn setup_logging() -> Result<()> {
    let path = "log.log";
    let file_sink = FileSink::builder().path(path).build_arc()?;
    let new_logger = Logger::builder().sink(file_sink).build_arc()?;
    spdlog::set_default_logger(new_logger);
    Ok(())
}

fn app(terminal: &mut DefaultTerminal, mut state: State) -> Result<()> {
    loop {
        update(&mut state)?;
        if state.exit {
            break
        }
        terminal.draw(|frame| render(frame, &state))?;
    }
    Ok(())
}

fn generate_test_data(typing_data: &TypingData, test_settings: &TestSettings) -> TestData {
    let (lines, total_length) = generate_test_lines(typing_data, test_settings);
    let goal_chars = generate_goal_chars(&lines, total_length);
    let input_chars = generate_input_chars(&lines, total_length);
    let char_positions = generate_char_positions(&lines, total_length);
    TestData {
        lines,
        goal_chars,
        input_chars,
        char_positions,
    }
}

fn generate_test_lines(typing_data: &TypingData, test_settings: &TestSettings) -> (Vec<Vec<String>>, usize) {
    let lines_count = typing_data.test_sizes[&test_settings.size];
    match test_settings.language {
        TestLanguage::Numbers => RandomWordGenerator::new(&typing_data.numbers, 6).generate_lines(lines_count),
        TestLanguage::Symbols => RandomWordGenerator::new(&typing_data.symbols, 4).generate_lines(lines_count),
        TestLanguage::Natural(index) => {
            let language_data = &typing_data.natural_languages[index];
            match test_settings.ngram {
                NgramType::Letters => RandomWordSelector::new(&language_data.bigrams).generate_lines(lines_count),
                NgramType::Bigrams => RandomWordSelector::new(&language_data.bigrams).generate_lines(lines_count),
                NgramType::Trigrams => RandomWordSelector::new(&language_data.trigrams).generate_lines(lines_count),
                NgramType::Words => {
                    let words = &language_data.words[&test_settings.words_rarity];
                    RandomWordSelector::new(&words.all_words).generate_lines(lines_count)
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
        Self::shuffle_vec(&mut alphabet_indices);
        RandomWordGenerator {
            alphabet,
            word_length,
            alphabet_indices,
            next_index: 0,
        }
    }

    fn shuffle_vec(vec: &mut [usize]) {
        let mut rng = rand::rng();
        vec.shuffle(&mut rng);
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
            Self::shuffle_vec(&mut self.alphabet_indices);
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
        let index = rand::random_range(0..self.words.len());
        self.words[index].clone()
    }
}

impl<'a> TestGenerator for RandomWordSelector<'a> {
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

fn update(state: &mut State) -> Result<()> {
    match event::read()? {
        Event::Key(key_event) if key_event.kind.is_press() => key_input(key_event, state),
        _ => {}
    }
    Ok(())
}

fn key_input(key_event: KeyEvent, state: &mut State) {
    info!("input code: {}, modifiers: {}", key_event.code, key_event.modifiers);

    if key_event.modifiers.contains(KeyModifiers::CONTROL) && key_event.code.is_char('c') {
        state.exit = true;
        return;
    };

    match key_event.code {
        KeyCode::Esc => {
            if state.show_settings {
                state.show_settings = false;
                return;
            }
        }
        KeyCode::Enter => {
            state.show_settings = !state.show_settings;
            return;
        },
        KeyCode::Tab => {
            state.test_settings.active_settings_tab = get_next(state.test_settings.active_settings_tab, &state.test_ui.settings_tabs);
            state.show_settings = true;
            return;
        },
        KeyCode::BackTab => {
            state.test_settings.active_settings_tab = get_previous(state.test_settings.active_settings_tab, &state.test_ui.settings_tabs);
            state.show_settings = true;
            return;
        },
        KeyCode::Down => if state.show_settings {
            match state.test_settings.active_settings_tab {
                SettingsTab::Language => state.test_settings.language = get_next(state.test_settings.language, &state.test_ui.languages),
                SettingsTab::NgramType => state.test_settings.ngram = get_next(state.test_settings.ngram, &state.test_ui.ngrams),
                SettingsTab::WordsRarity => state.test_settings.words_rarity = get_next(state.test_settings.words_rarity, &state.test_ui.words_rarities),
                SettingsTab::Size => state.test_settings.size = get_next(state.test_settings.size, &state.test_ui.sizes),
                _ => {}
            };
            rebuild_ui(&mut state.test_ui, &state.typing_data, &state.test_settings);
            start_new_test(state);
            return;
        },
        KeyCode::Up => if state.show_settings {
            match state.test_settings.active_settings_tab {
                SettingsTab::Language => state.test_settings.language = get_previous(state.test_settings.language, &state.test_ui.languages),
                SettingsTab::NgramType => state.test_settings.ngram = get_previous(state.test_settings.ngram, &state.test_ui.ngrams),
                SettingsTab::WordsRarity => state.test_settings.words_rarity = get_previous(state.test_settings.words_rarity, &state.test_ui.words_rarities),
                SettingsTab::Size => state.test_settings.size = get_previous(state.test_settings.size, &state.test_ui.sizes),
                _ => {}
            };
            rebuild_ui(&mut state.test_ui, &state.typing_data, &state.test_settings);
            start_new_test(state);
            return;
        },
        _ => {}
    }

    if state.show_settings {
        return;
    }

    match state.test_state {
        TestState::Waiting => match key_event.code {
            KeyCode::Esc => start_new_test(state),
            KeyCode::Char(key_char) => {
                push_new_char(state, key_char);
                state.test_start_time = Instant::now();
                state.test_state = TestState::Running;
            },
            _ => {}
        }
        TestState::Running => match key_event.code {
            KeyCode::Esc => reset_current_test(state),
            KeyCode::Backspace => {
                if state.test_data.input_chars.len() > 1 {
                    state.test_data.input_chars.pop();
                    // should we count backspaces in wpm/cpm? debatable
                    state.total_keys_pressed += 1;
                } else {
                    reset_current_test(state);
                }
            },
            KeyCode::Char(key_char) => {
                push_new_char(state, key_char);
                if state.test_data.input_chars.len() >= state.test_data.goal_chars.len() - 1 {
                    state.test_end_time = Instant::now();
                    state.test_state = TestState::Finished;
                }
            },
            _ => {}
        }
        TestState::Finished => match key_event.code {
            KeyCode::Esc => reset_current_test(state),
            KeyCode::Char(' ') => start_new_test(state),
            _ => {}
        }
    }
}

fn push_new_char(state: &mut State, new_char: char) {
    let test_data = &mut state.test_data;

    test_data.input_chars.push(new_char);
    state.total_keys_pressed += 1;

    let new_char_index = test_data.input_chars.len() - 1;
    let goal_char = test_data.goal_chars[new_char_index];
    if new_char != goal_char {
        state.wrong_keys_pressed += 1;
    }
}

fn start_new_test(state: &mut State) {
    state.test_data = generate_test_data(&state.typing_data, &state.test_settings);
    state.test_state = TestState::Waiting;
    state.total_keys_pressed = 0;
    state.wrong_keys_pressed = 0;
}

fn reset_current_test(state: &mut State) {
    state.test_data.input_chars.clear();
    state.test_state = TestState::Waiting;
    state.total_keys_pressed = 0;
    state.wrong_keys_pressed = 0;
}

fn render(frame: &mut Frame, state: &State) {
    let frame_area = frame.area();

    // draw background border
    let title_line = Line::from("drochetype");
    let test_state_line = match state.test_state {
        TestState::Waiting => Line::from("waiting"),
        TestState::Running => Line::from("running").fg(Color::Green),
        TestState::Finished => Line::from("finished").fg(Color::Yellow),
    };
    let block = Block::default()
        .title_top(title_line.centered())
        .title_bottom(test_state_line)
        .borders(Borders::ALL);

    frame.render_widget(block, frame_area);

    // draw main text
    // TODO if stuff does not fit with max_text_height, then use text_height
    let text = generate_text_from_test(&state.test_data);
    let text_height = text.height();
    let max_text_height = *state.typing_data.test_sizes.values().max().expect("no items in test_sizes array?");
    let text_area = Rect::new(
        get_center(frame_area.width, MAX_LINE_LENGTH as u16),
        get_center(frame_area.height, max_text_height as u16),
        MAX_LINE_LENGTH as u16,
        max_text_height as u16
    );
    frame.render_widget(text, text_area);

    // draw cursor
    if !state.show_settings {
        let cursor_position_index = state.test_data.input_chars.len();
        let cursor_position_local = state.test_data.char_positions[cursor_position_index];
        frame.set_cursor_position(cursor_position_local + text_area.as_position().into());
    }

    // draw settings tabs
    let separator = " • ";
    let active_settings_tab_index = get_index(state.test_settings.active_settings_tab, &state.test_ui.settings_tabs);
    let active_settings_tab_style = Style::default().add_modifier(Modifier::UNDERLINED);
    let mut tab_names = Vec::with_capacity(state.test_ui.settings_tabs.len() * 2 + 1); // reserve space for tab names and separators

    tab_names.push(Span::from(separator));
    for settings_tab in &state.test_ui.settings_tabs {
        let settings_tab_name = settings_tab.get_name(&state.typing_data);
        if *settings_tab == state.test_settings.active_settings_tab {
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
    if state.test_state == TestState::Finished {
        let elapsed_time = state.test_end_time.duration_since(state.test_start_time);
        let elapsed_seconds = elapsed_time.as_secs();
        let time_string = format!("{0:02}:{1:02}", elapsed_seconds / 60, elapsed_seconds % 60);
        let accuracy = (state.total_keys_pressed - state.wrong_keys_pressed) as f64 / state.total_keys_pressed as f64 * 100.0;
        let accuracy_string = format!("{}%", accuracy.floor());
        let cpm = 60.0 * state.total_keys_pressed as f64 / elapsed_time.as_secs_f64();
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
        let title_name = state.test_settings.active_settings_tab.get_name(&state.typing_data);
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
    match state.test_settings.active_settings_tab {
        SettingsTab::Language => {
            get_settings_options_text(&state.test_ui.languages, state.test_settings.language, &state.typing_data)
        },
        SettingsTab::NgramType => {
            get_settings_options_text(&state.test_ui.ngrams, state.test_settings.ngram, &state.typing_data)
        },
        SettingsTab::WordsRarity => {
            get_settings_options_text(&state.test_ui.words_rarities, state.test_settings.words_rarity, &state.typing_data)
        },
        SettingsTab::IncludeLetter => {
            Text::from(vec![
                Line::from("* a b c d e f").centered(),
                Line::from("g h i j k l m").centered(),
                Line::from("n o p q r s t").centered(),
                Line::from("u v w x y z  ").centered(),
            ])
        },
        SettingsTab::SelectLetters => {
            Text::from(vec![
                Line::from("a b c d e f g").centered(),
                Line::from("h i j k l m n").centered(),
                Line::from("o p q r s t u").centered(),
                Line::from("v w x y z    ").centered(),
            ])
        },
        SettingsTab::Size => {
            get_settings_options_text(&state.test_ui.sizes, state.test_settings.size, &state.typing_data)
        },
    }
}

fn get_settings_options_text<'a, T: WithName + Copy + PartialEq>(options: &[T], active_option: T, typing_data: &TypingData) -> Text<'a> {
    let mut lines = Vec::with_capacity(options.len());
    for option in options {
        let name = option.get_name(typing_data);
        if *option == active_option {
            lines.push(Line::styled(name, Style::default().fg(Color::Yellow)).centered());
        } else {
            lines.push(Line::styled(name, Style::default()).centered());
        }
    }
    Text::from(lines)
}

fn generate_text_from_test<'a>(test_data: &TestData) -> Text<'a> {
    let test_lines = &test_data.lines;
    let mut lines = Vec::with_capacity(test_lines.len());

    let mut span_index = 0;
    for test_line in test_lines {
        let mut line_spans = Vec::with_capacity(MAX_LINE_LENGTH);
        for test_word in test_line {
            for char in test_word.chars() {
                let span = get_char_span(span_index, &test_data.goal_chars, &test_data.input_chars);
                line_spans.push(span);
                span_index += 1;
            }
            {
                let span = get_char_span(span_index, &test_data.goal_chars, &test_data.input_chars);
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

fn load_typing_data() -> TypingData {
    let root = Path::new("data");
    let numbers = load_from_json_file::<Vec<char>>(&root.join("numbers.json"));
    let symbols = load_from_json_file::<Vec<char>>(&root.join("symbols.json"));
    let languages = load_from_json_file::<Vec<DataLanguage>>(&root.join("languages.json"));
    let mut natural_languages = Vec::with_capacity(languages.len());

    for language in languages {
        let name = language.name;
        let alphabet = load_from_json_file::<Vec<char>>(&root.join(language.alphabet));
        let alphabet_dict = build_alphabet_dict(&alphabet);
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
            (WordsRarity::VeryCommon, NaturalLanguageWords {
                per_letter: build_letter_to_words_dict(&words_very_common, &alphabet),
                all_words: words_very_common,
            }),
            (WordsRarity::Common, NaturalLanguageWords {
                per_letter: build_letter_to_words_dict(&words_common, &alphabet),
                all_words: words_common,
            }),
            (WordsRarity::Rare, NaturalLanguageWords {
                per_letter: build_letter_to_words_dict(&words_rare, &alphabet),
                all_words: words_rare,
            }),
            (WordsRarity::VeryRare, NaturalLanguageWords {
                per_letter: build_letter_to_words_dict(&words_very_rare, &alphabet),
                all_words: words_very_rare,
            }),
        ]);

        natural_languages.push(TypingDataNaturalLanguage {
            name,
            alphabet,
            alphabet_dict,
            bigrams,
            trigrams,
            words,
        });
    }

    TypingData {
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

fn build_alphabet_dict(alphabet: &[char]) -> HashMap<char, usize> {
    let mut result = HashMap::new();
    for (i, letter) in alphabet.iter().enumerate() {
        result.insert(*letter, i);
    }
    result
}

fn build_letter_to_words_dict(words: &[String], alphabet: &Vec<char>) -> HashMap<char, Vec<usize>> {
    let mut result = HashMap::new();

    for letter in alphabet {
        result.insert(*letter, Vec::new());
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
