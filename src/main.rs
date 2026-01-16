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

macro_rules! strings {
    ($($x:expr),*) => ([$($x.to_string()),*]);
}

const MAX_LINE_LENGTH: usize = 45; // TODO add different widths: narrow, medium, wide
const WORD_RARITIES_COUNT: usize = 4;
const TEST_SIZES_COUNT: usize = 4;

struct TestSettings {
    language: TestLanguage,
    ngram: NgramType,
    word_rarity_index: usize,
    natural_language_configs: HashMap<usize, TypingConfigNaturalLanguage>,
    size_index: usize,
}

fn build_settings_tabs(test_settings: &TestSettings, active_tab: &SettingsTab) -> (Vec<SettingsTab>, usize) {
    let tabs = match test_settings.language {
        TestLanguage::Numbers => vec![SettingsTab::Language, SettingsTab::Size],
        TestLanguage::Symbols => vec![SettingsTab::Language, SettingsTab::Size],
        TestLanguage::Natural(_) => match test_settings.ngram {
            NgramType::Letters => vec![SettingsTab::Language, SettingsTab::NgramType, SettingsTab::SelectLetters, SettingsTab::Size],
            NgramType::Bigrams => vec![SettingsTab::Language, SettingsTab::NgramType, SettingsTab::Size],
            NgramType::Trigrams => vec![SettingsTab::Language, SettingsTab::NgramType, SettingsTab::Size],
            NgramType::Words => vec![SettingsTab::Language, SettingsTab::NgramType, SettingsTab::WordsRarity, SettingsTab::IncludeLetter, SettingsTab::Size],
        },
    };

    let active_tab_index = tabs.iter().position(|tab| tab == active_tab).expect("active tab was not in the tab list?");
    (tabs, active_tab_index)
}

enum TestLanguage {
    Numbers,
    Symbols,
    Natural(usize)
}

enum NgramType {
    Letters,
    Bigrams,
    Trigrams,
    Words,
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
    numbers: Vec<String>,
    symbols: Vec<String>,
    natural_languages_data: Vec<TypingDataNaturalLanguage>,
    test_sizes: [usize; TEST_SIZES_COUNT],
}

struct TypingDataNaturalLanguage {
    name: String,
    alphabet: Vec<char>,
    alphabet_dict: HashMap<char, usize>,
    bigrams: Vec<String>,
    trigrams: Vec<String>,
    words: [NaturalLanguageWords; WORD_RARITIES_COUNT],
}

struct NaturalLanguageWords {
    all_words: Vec<String>,
    per_letter: HashMap<char, Vec<usize>>,
}

struct Localization {
    word_rarities: [String; WORD_RARITIES_COUNT],
    test_sizes: [String; TEST_SIZES_COUNT]
}

struct State {
    typing_data: TypingData,
    localization: Localization,
    test_data: TestData,
    test_state: TestState,
    test_start_time: Instant,
    test_end_time: Instant,
    total_keys_pressed: usize,
    wrong_keys_pressed: usize,
    show_settings: bool,
    test_settings: TestSettings,
    active_settings_tab: SettingsTab,
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

#[derive(PartialEq)]
#[derive(Copy)]
#[derive(Clone)]
enum SettingsTab {
    Language,
    NgramType,
    WordsRarity,
    IncludeLetter,
    SelectLetters,
    Size,
}

fn main() {
    setup_logging();

    let typing_data = load_typing_data();
    let localization = load_localization();
    let test_settings = get_default_test_settings(&typing_data);
    let test_data = generate_test_data(&typing_data, &test_settings);
    let time = Instant::now();
    let state = State {
        typing_data,
        localization,
        test_data,
        test_state: TestState::Waiting,
        test_start_time: time,
        test_end_time: time,
        total_keys_pressed: 0,
        wrong_keys_pressed: 0,
        show_settings: false,
        test_settings: test_settings,
        active_settings_tab: SettingsTab::Language,
        exit: false,
    };

    ratatui::run(|terminal| app(terminal, state));
}

fn get_default_test_settings(typing_data: &TypingData) -> TestSettings {
    let natural_languages_count = typing_data.natural_languages_data.len();
    TestSettings {
        language: TestLanguage::Natural(0),
        ngram: NgramType::Words,
        word_rarity_index: 1,
        natural_language_configs: HashMap::with_capacity(natural_languages_count),
        size_index: 1,
    }
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
    let (lines, total_length) = generate_test_lines(&typing_data, &test_settings);
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
    let mut line_index = 0;
    let mut line_length = 0;
    let mut total_length = 0;

    let lines_count = typing_data.test_sizes[test_settings.size_index];
    let max_line_length = MAX_LINE_LENGTH;
    let mut result_lines = Vec::with_capacity(lines_count);
    let mut current_line = Vec::new();

    loop {
        let next_word = generate_next_word(typing_data, test_settings);
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

fn generate_next_word(typing_data: &TypingData, test_settings: &TestSettings) -> String {
    let words = &typing_data.natural_languages_data[0].words[test_settings.word_rarity_index].all_words;
    let index = rand::random_range(0..words.len());
    words[index].clone()
}

fn generate_goal_chars(lines: &Vec<Vec<String>>, total_length: usize) -> Vec<char> {
    let mut goal_chars = Vec::with_capacity(total_length);
    for line in lines {
        for word in line {
            for char in word.chars() {
                goal_chars.push(char.clone());
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
    let mut y = 0;
    for line in lines {
        let mut x = 0;
        for word in line {
            for char in word.chars() {
                char_positions.push(Position::new(x, y));
                x += 1;
            }
            {
                char_positions.push(Position::new(x, y));
                x += 1;
            }
        }
        y += 1;
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
            let (settings_tabs, active_settings_tab_index) = build_settings_tabs(&state.test_settings, &state.active_settings_tab);
            let new_active_settings_tab_index = (active_settings_tab_index + 1) % settings_tabs.len();
            state.active_settings_tab = settings_tabs[new_active_settings_tab_index];
            state.show_settings = true;
            return;
        },
        KeyCode::BackTab => {
            let (settings_tabs, active_settings_tab_index) = build_settings_tabs(&state.test_settings, &state.active_settings_tab);
            let new_active_settings_tab_index = (settings_tabs.len() + active_settings_tab_index - 1) % settings_tabs.len();
            state.active_settings_tab = settings_tabs[new_active_settings_tab_index];
            state.show_settings = true;
            return;
        },
        KeyCode::Down => {
            if state.show_settings {
                if state.active_settings_tab == SettingsTab::WordsRarity {
                    state.test_settings.word_rarity_index = (state.test_settings.word_rarity_index + 1) % WORD_RARITIES_COUNT;
                    start_new_test(state);
                    return;
                }
                if state.active_settings_tab == SettingsTab::Size {
                    state.test_settings.size_index = (state.test_settings.size_index + 1) % TEST_SIZES_COUNT;
                    start_new_test(state);
                    return;
                }
            }
        },
        KeyCode::Up => {
            if state.show_settings {
                if state.active_settings_tab == SettingsTab::WordsRarity {
                    state.test_settings.word_rarity_index = (WORD_RARITIES_COUNT + state.test_settings.word_rarity_index - 1) % WORD_RARITIES_COUNT;
                    start_new_test(state);
                    return;
                }
                if state.active_settings_tab == SettingsTab::Size {
                    state.test_settings.size_index = (TEST_SIZES_COUNT + state.test_settings.size_index - 1) % TEST_SIZES_COUNT;
                    start_new_test(state);
                    return;
                }
            }
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
            }
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
    let is_correct = new_char == goal_char;
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
    let max_text_height = state.typing_data.test_sizes.iter().max().expect("no items in test_sizes array?").clone();
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
    let (settings_tabs, active_settings_tab_index) = build_settings_tabs(&state.test_settings, &state.active_settings_tab);
    let active_settings_tab_style = Style::default().add_modifier(Modifier::UNDERLINED);
    let mut tab_names = Vec::with_capacity(settings_tabs.len() * 2 - 1); // reserve space for tab names and separators
    for (i, settings_tab) in settings_tabs.iter().enumerate() {
        let settings_tab_name = get_settings_tab_name(settings_tab);
        if i == active_settings_tab_index {
            tab_names.push(Span::styled(settings_tab_name, active_settings_tab_style));
        } else {
            tab_names.push(Span::from(settings_tab_name));
        }
        if i < settings_tabs.len() - 1 {
            tab_names.push(Span::from(separator));
        }
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
        let text = get_settings_options(&state);
        let title_name = get_settings_tab_name(&state.active_settings_tab);
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
    let mut x: usize = 0;
    for (i, tab_name) in tab_names.iter().enumerate() {
        if i / 2 == tab_index {
            break;
        }
        x += tab_name.width();
    }
    x as u16
}

fn get_settings_tab_name(tab: &SettingsTab) -> String {
    let name = match tab {
        SettingsTab::Language => "language",
        SettingsTab::NgramType => "ngram type",
        SettingsTab::WordsRarity => "words rarity",
        SettingsTab::IncludeLetter => "include letter",
        SettingsTab::SelectLetters => "select letters",
        SettingsTab::Size => "test size",
    };
    name.to_string()
}

fn get_settings_options(state: &State) -> Text {
    match state.active_settings_tab {
        SettingsTab::Language => {
            Text::from(vec![
                Line::from("numbers").centered(),
                Line::from("symbols").centered(),
                Line::from("english").centered().style(Style::default().fg(Color::Yellow)),
                Line::from("russian").centered(),
            ])
        },
        SettingsTab::NgramType => {
            Text::from(vec![
                Line::from("letters").centered(),
                Line::from("bigrams").centered(),
                Line::from("trigrams").centered(),
                Line::from("words").centered().style(Style::default().fg(Color::Yellow)),
            ])
        },
        SettingsTab::WordsRarity => {
            get_settings_options_from_names(&state.localization.word_rarities, state.test_settings.word_rarity_index)
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
                Line::from("test").centered(),
                Line::from("test").centered(),
                Line::from("test").centered(),
                Line::from("test").centered(),
            ])
        },
        SettingsTab::Size => {
            get_settings_options_from_names(&state.localization.test_sizes, state.test_settings.size_index)
        },
    }
}

fn get_settings_options_from_names(names: &[String], active_option_index: usize) -> Text {
    let mut lines = Vec::with_capacity(names.len());
    for (i, name) in names.iter().enumerate() {
        if i == active_option_index {
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

fn get_char_span<'a>(char_index: usize, goal_chars: &Vec<char>, input_chars: &Vec<char>) -> Span<'a> {
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
    let numbers = load_from_json_file::<Vec<String>>(&root.join("numbers.json"));
    let symbols = load_from_json_file::<Vec<String>>(&root.join("symbols.json"));
    let languages = load_from_json_file::<Vec<DataLanguage>>(&root.join("languages.json"));
    let mut natural_languages_data = Vec::with_capacity(languages.len());

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

        let words = [
            NaturalLanguageWords {
                per_letter: build_letter_to_words_dict(&words_very_common, &alphabet),
                all_words: words_very_common,
            },
            NaturalLanguageWords {
                per_letter: build_letter_to_words_dict(&words_common, &alphabet),
                all_words: words_common,
            },
            NaturalLanguageWords {
                per_letter: build_letter_to_words_dict(&words_rare, &alphabet),
                all_words: words_rare,
            },
            NaturalLanguageWords {
                per_letter: build_letter_to_words_dict(&words_very_rare, &alphabet),
                all_words: words_very_rare,
            },
        ];

        natural_languages_data.push(TypingDataNaturalLanguage {
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
        natural_languages_data,
        test_sizes: [1, 3, 6, 12],
    }
}

fn load_localization() -> Localization {
    Localization {
        word_rarities: strings!["very common", "common", "rare", "very rare"],
        test_sizes: strings!["very small", "small", "medium", "large"],
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
