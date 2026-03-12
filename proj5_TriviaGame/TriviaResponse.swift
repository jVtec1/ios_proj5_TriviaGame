//
//  TriviaResponse.swift
//  proj5_TriviaGame
//
//  Created by Andy Espinoza on 3/12/26.
//

import Foundation

struct TriviaResponse: Codable {
    let response_code: Int
    let results: [TriviaQuestion]
}

struct TriviaQuestion: Codable, Identifiable {
    let id = UUID()
    let category: String
    let type: String            // "multiple" or "boolean"
    let difficulty: String      // "easy", "medium", "hard"
    let question: String
    let correct_answer: String
    let incorrect_answers: [String]
}
