//
// Created by Banghua Zhao on 26/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//
  
import Foundation

struct ChatMessage: Codable, Identifiable {
    let id = UUID()
    let role: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case role, content
    }
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: ChatMessage
    }
}

class ChatGPTService {
    private let apiKey = Config.apiKey
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-5.1"
    
    func sendMessage(messages: [ChatMessage]) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw ChatGPTError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: 0.7
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatGPTError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            switch httpResponse.statusCode {
            case 401:
                throw ChatGPTError.unauthorized
            case 429:
                throw ChatGPTError.tooManyRequest
            default:
                throw ChatGPTError.invalidResponse
            }
        }
        
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        
        guard let content = chatResponse.choices.first?.message.content else {
            throw ChatGPTError.noContent
        }
        
        return content
    }
}

enum ChatGPTError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noContent
    case unauthorized
    case tooManyRequest
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .noContent:
            return "No content in response"
        case .unauthorized:
            return "Unauthorized. Please double check API key"
        case .tooManyRequest:
            return "Too many request. Please double check the API key has enough quota"
        }
    }
}
