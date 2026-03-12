//
//  ContentView.swift
//  proj5_TriviaGame
//
//  Created by Andy Espinoza on 3/12/26.
//

import SwiftUI

struct ContentView: View {
    // MARK: - Options state
    @State private var amount: Int = 10
    @State private var categories: [TriviaCategory] = []
    @State private var selectedCategoryId: Int? = nil // nil = any category
    @State private var difficulty: Difficulty = .any
    @State private var questionType: QuestionType = .any

    // MARK: - Game state
    @State private var questions: [TriviaQuestion] = []
    @State private var selections: [UUID: String] = [:] // question.id -> chosen answer
    @State private var showQuiz = false
    @State private var isLoading = false

    // Submit / score
    @State private var showScoreAlert = false
    @State private var scoreText = ""

    var body: some View {
        NavigationStack {
            OptionsView(
                amount: $amount,
                categories: categories,
                selectedCategoryId: $selectedCategoryId,
                difficulty: $difficulty,
                questionType: $questionType,
                isLoading: isLoading,
                startTapped: {
                    Task { await startGame() }
                }
            )
            .navigationTitle("Super Trivia")
            .navigationDestination(isPresented: $showQuiz) {
                QuizView(
                    questions: questions,
                    selections: $selections,
                    submitTapped: submitQuiz,
                    resetTapped: resetToOptions
                )
                .navigationTitle("Trivia")
                .alert("Your Score", isPresented: $showScoreAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(scoreText)
                }
            }
            .task {
                // load categories once
                await loadCategories()
            }
        }
    }

    // MARK: - Networking
    private func loadCategories() async {
        guard let url = URL(string: "https://opentdb.com/api_category.php") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(CategoryResponse.self, from: data)
            categories = decoded.trivia_categories
        } catch {
            // keep it simple for class project; you could show an alert here
            categories = []
        }
    }

    private func startGame() async {
        isLoading = true
        defer { isLoading = false }

        selections = [:]
        questions = []

        var comps = URLComponents(string: "https://opentdb.com/api.php")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "amount", value: "\(amount)")
        ]

        if let catId = selectedCategoryId {
            items.append(URLQueryItem(name: "category", value: "\(catId)"))
        }
        if difficulty != .any {
            items.append(URLQueryItem(name: "difficulty", value: difficulty.rawValue))
        }
        if questionType != .any {
            items.append(URLQueryItem(name: "type", value: questionType.rawValue))
        }

        comps.queryItems = items

        do {
            let (data, _) = try await URLSession.shared.data(from: comps.url!)
            let decoded = try JSONDecoder().decode(TriviaResponse.self, from: data)

            // Handle OpenTDB response codes (0 success, 1 no results, etc.) :contentReference[oaicite:8]{index=8}
            guard decoded.response_code == 0 else {
                // For class: simplest handling
                questions = []
                return
            }

            questions = decoded.results
            showQuiz = true
        } catch {
            questions = []
        }
    }

    // MARK: - Submit / Score
    private func submitQuiz() {
        let total = questions.count
        var correct = 0

        for q in questions {
            if selections[q.id] == q.correct_answer {
                correct += 1
            }
        }

        scoreText = "\(correct) / \(total)"
        showScoreAlert = true
    }

    private func resetToOptions() {
        showQuiz = false
        questions = []
        selections = [:]
    }
}

// MARK: - Supporting models for categories + options
struct CategoryResponse: Codable {
    let trivia_categories: [TriviaCategory]
}

struct TriviaCategory: Codable, Identifiable {
    let id: Int
    let name: String
}

enum Difficulty: String, CaseIterable, Identifiable {
    case any = ""
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"

    var id: String { rawValue }
    var label: String { self == .any ? "Any" : rawValue.capitalized }
}

enum QuestionType: String, CaseIterable, Identifiable {
    case any = ""
    case multiple = "multiple"
    case boolean = "boolean"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .any: return "Any"
        case .multiple: return "Multiple Choice"
        case .boolean: return "True / False"
        }
    }
}

// MARK: - Options View
struct OptionsView: View {
    @Binding var amount: Int
    let categories: [TriviaCategory]
    @Binding var selectedCategoryId: Int?
    @Binding var difficulty: Difficulty
    @Binding var questionType: QuestionType

    let isLoading: Bool
    let startTapped: () -> Void

    var body: some View {
        Form {
            Section("Number of Questions") {
                Stepper("Amount: \(amount)", value: $amount, in: 1...20)
            }
            .listRowBackground(Color.blue.opacity(0.3)) // Customizing row background
            .listSectionSeparator(.hidden)

            Section("Category") {
                Picker("Category", selection: Binding(
                    get: { selectedCategoryId ?? -1 },
                    set: { selectedCategoryId = ($0 == -1) ? nil : $0 }
                )) {
                    Text("Any").tag(-1)
                    ForEach(categories) { cat in
                        Text(cat.name).tag(cat.id)
                    }
                }
            }
            .listRowBackground(Color.pink.opacity(0.2))

            Section("Difficulty") {
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases) { d in
                        Text(d.label).tag(d)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.green.opacity(0.3))

            Section("Type") {
                Picker("Type", selection: $questionType) {
                    ForEach(QuestionType.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
            }
            .listRowBackground(Color.orange.opacity(0.3))

            Section {
                Button {
                    startTapped()
                } label: {
                    HStack {
                        Spacer()
                        if isLoading { ProgressView() }
                        Text(isLoading ? "Loading…" : "Start Game")
                        Spacer()
                    }
                }
                .disabled(isLoading)
            }
            .listRowBackground(Color.indigo.opacity(0.2))
        }
    }
}

// MARK: - Quiz View (List style = easiest)
struct QuizView: View {
    let questions: [TriviaQuestion]
    @Binding var selections: [UUID: String]

    let submitTapped: () -> Void
    let resetTapped: () -> Void

    var body: some View {
        VStack {
            List {
                ForEach(questions) { q in
                    Section(q.question.htmlDecoded) {
                        ForEach(shuffledAnswers(for: q), id: \.self) { ans in
                            HStack {
                                Text(ans.htmlDecoded)
                                Spacer()
                                if selections[q.id] == ans {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selections[q.id] = ans
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Reset") { resetTapped() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Submit") { submitTapped() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selections.count < questions.count) // require all answered
            }
            .padding()
        }
    }

    private func shuffledAnswers(for q: TriviaQuestion) -> [String] {
        // For boolean, the API provides correct + one incorrect; still works.
        return ([q.correct_answer] + q.incorrect_answers).shuffled()
    }
}

#Preview {
    ContentView()
}
