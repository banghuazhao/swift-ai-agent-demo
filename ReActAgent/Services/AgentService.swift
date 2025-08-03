//
// Created by Banghua Zhao on 26/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//
  
import Foundation

// MARK: - Agent Models
struct AgentStep: Identifiable {
    let id = UUID()
    let type: StepType
    let content: String
    let timestamp: Date
    
    enum StepType {
        case thought
        case action
        case observation
        case finalAnswer
        case error
    }
}

struct AgentTool {
    let name: String
    let description: String
    let action: ([String]) async throws -> String
}

enum AgentError: LocalizedError {
    case noActionFound
    case toolNotFound(String)
    case invalidActionFormat
    case executionError(String)
    
    var errorDescription: String? {
        switch self {
        case .noActionFound:
            return "No action found in model response"
        case .toolNotFound(let name):
            return "Tool '\(name)' not found"
        case .invalidActionFormat:
            return "Invalid action format"
        case .executionError(let message):
            return "Execution error: \(message)"
        }
    }
}

// MARK: - Agent Service
class AgentService: ObservableObject {
    @Published var steps: [AgentStep] = []
    @Published var isRunning = false
    
    private let chatGPTService: ChatGPTService
    private var tools: [String: AgentTool] = [:]
    private var messages: [ChatMessage] = []
    
    init(chatGPTService: ChatGPTService = ChatGPTService()) {
        self.chatGPTService = chatGPTService
        setupTools()
    }
    
    func runAgent(with userInput: String) async {
        await MainActor.run {
            self.isRunning = true
            self.steps.removeAll()
            self.messages.removeAll()
        }
        
        // Setup initial messages
        let systemPrompt = generateSystemPrompt()
        messages.append(ChatMessage(role: "system", content: systemPrompt))
        messages.append(ChatMessage(role: "user", content: "<question>\(userInput)</question>"))
        
        do {
            while true {
                // Request model response
                print(messages)
                let content = try await chatGPTService.sendMessage(messages: messages)
                messages.append(ChatMessage(role: "assistant", content: content))
                                
                // Parse and handle thought
                if let thought = extractThought(from: content) {
                    await addStep(.thought, content: thought)
                }
                
                // Check for final answer
                if let finalAnswer = extractFinalAnswer(from: content) {
                    await addStep(.finalAnswer, content: finalAnswer)
                    break
                }
                
                // Parse and execute action
                if let action = extractAction(from: content) {
                    await addStep(.action, content: action)
                    
                    do {
                        let observation = try await executeAction(action)
                        await addStep(.observation, content: observation)
                        
                        // Add observation to messages
                        messages.append(ChatMessage(role: "user", content: "<observation>\(observation)</observation>"))
                    } catch {
                        let errorMessage = error.localizedDescription
                        await addStep(.error, content: errorMessage)
                        messages.append(ChatMessage(role: "user", content: "<observation>Error: \(errorMessage)</observation>"))
                    }
                } else {
                    throw AgentError.noActionFound
                }
            }
        } catch {
            await addStep(.error, content: error.localizedDescription)
        }
        
        await MainActor.run {
            self.isRunning = false
        }
    }
    
    @MainActor
    private func addStep(_ type: AgentStep.StepType, content: String) {
        let step = AgentStep(type: type, content: content, timestamp: Date())
        steps.append(step)
    }
    
    private func setupTools() {
        // Read file tool
        tools["read_file"] = AgentTool(
            name: "read_file",
            description: "Read contents of a file"
        ) { args in
            guard let relativePath = args.first else {
                throw AgentError.executionError("File path required")
            }
            
            // Resolve the file path relative to the temporary directory
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent(relativePath)
            
            do {
                let content = try String(contentsOfFile: fileURL.path(), encoding: .utf8)
                return content
            } catch {
                throw AgentError.executionError("Could not read file: \(error.localizedDescription)")
            }
        }
        
        // Write file tool
        tools["write_to_file"] = AgentTool(
            name: "write_to_file",
            description: "Write content to a file"
        ) { args in
            guard args.count >= 2 else {
                throw AgentError.executionError("File path and content required")
            }
            
            let relativePath = args[0]
            let content = args[1].replacingOccurrences(of: "\\n", with: "\n")
            
            // Resolve the file path relative to the temporary directory
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent(relativePath)
            
            print(fileURL.path())
            
            do {
                let directoryURL = fileURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                
                try content.write(toFile: fileURL.path(), atomically: true, encoding: .utf8)
                return "Write successful"
            } catch {
                throw AgentError.executionError("Could not write file: \(error.localizedDescription)")
            }
        }
        
        // Get current time tool
        tools["get_current_time"] = AgentTool(
            name: "get_current_time",
            description: "Get current date and time"
        ) { _ in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return formatter.string(from: Date())
        }
        
        // Simple calculation tool
        tools["calculate"] = AgentTool(
            name: "calculate",
            description: "Perform simple mathematical calculations"
        ) { args in
            guard let expression = args.first else {
                throw AgentError.executionError("Expression required")
            }
            
            let mathExpression = NSExpression(format: expression)
            if let result = mathExpression.expressionValue(with: nil, context: nil) as? NSNumber {
                return "\(result)"
            } else {
                throw AgentError.executionError("Invalid mathematical expression")
            }
        }
    }
    
    private func executeAction(_ action: String) async throws -> String {
        let (toolName, args) = try parseAction(action)
        
        guard let tool = tools[toolName] else {
            throw AgentError.toolNotFound(toolName)
        }
        
        return try await tool.action(args)
    }
    
    private func parseAction(_ action: String) throws -> (String, [String]) {
        let trimmedAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First try to match format: tool_name(arg1, arg2, ...)
        let patternWithArgs = #"(\w+)\((.*)\)"#
        let regexWithArgs = try NSRegularExpression(pattern: patternWithArgs, options: [.dotMatchesLineSeparators])
        let nsRange = NSRange(trimmedAction.startIndex..<trimmedAction.endIndex, in: trimmedAction)
        
        if let match = regexWithArgs.firstMatch(in: trimmedAction, options: [], range: nsRange) {
            // Found format with parentheses
            let toolName = String(trimmedAction[Range(match.range(at: 1), in: trimmedAction)!])
            let argsString = String(trimmedAction[Range(match.range(at: 2), in: trimmedAction)!])
            
            let args = parseArguments(argsString)
            return (toolName, args)
        }
        
        // Try to match format: tool_name (no arguments, no parentheses)
        let patternNoArgs = #"^(\w+)$"#
        let regexNoArgs = try NSRegularExpression(pattern: patternNoArgs, options: [])
        
        if let match = regexNoArgs.firstMatch(in: trimmedAction, options: [], range: nsRange) {
            // Found format without parentheses
            let toolName = String(trimmedAction[Range(match.range(at: 1), in: trimmedAction)!])
            return (toolName, [])
        }
        
        // Neither format matched
        throw AgentError.invalidActionFormat
    }
    
    private func parseArguments(_ argsString: String) -> [String] {
        var args: [String] = []
        var currentArg = ""
        var inQuotes = false
        var quoteChar: Character = "\""
        var i = argsString.startIndex
        
        while i < argsString.endIndex {
            let char = argsString[i]
            
            if !inQuotes {
                if char == "\"" || char == "'" {
                    inQuotes = true
                    quoteChar = char
                } else if char == "," {
                    args.append(currentArg.trimmingCharacters(in: .whitespaces))
                    currentArg = ""
                    i = argsString.index(after: i)
                    continue
                } else {
                    currentArg.append(char)
                }
            } else {
                if char == quoteChar {
                    inQuotes = false
                } else {
                    currentArg.append(char)
                }
            }
            
            i = argsString.index(after: i)
        }
        
        if !currentArg.trimmingCharacters(in: .whitespaces).isEmpty {
            args.append(currentArg.trimmingCharacters(in: .whitespaces))
        }
        
        return args
    }
    
    // MARK: - Content Parsing
    private func extractThought(from content: String) -> String? {
        return extractContent(from: content, tag: "thought")
    }
    
    private func extractAction(from content: String) -> String? {
        return extractContent(from: content, tag: "action")
    }
    
    private func extractFinalAnswer(from content: String) -> String? {
        return extractContent(from: content, tag: "final_answer")
    }
    
    private func extractContent(from text: String, tag: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = regex?.firstMatch(in: text, options: [], range: nsRange) {
            return String(text[Range(match.range(at: 1), in: text)!]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func generateSystemPrompt() -> String {
        let toolList = tools.map { key, value in
            "- \(key): \(value.description)"
        }.joined(separator: "\n")
        
        return """
        You are tasked with solving a problem by breaking it into logical steps. 
        
        For each step, use <thought> to explain your reasoning, then select an <action> using one of the available tools or provide a <final_answer> if the solution is complete. 
        
        After an <action>, you will receive an <observation> from the environment or tools. Continue this process until you can provide a <final_answer>.

        Strictly use the following XML tag format for all steps:
        - <question> User question </question>
        - <thought> Reasoning for the next step </thought>
        - <action> Tool operation to execute </action>
        - <observation> Results from tools or environment </observation>
        - <final_answer> Final solution to the question </final_answer>

        Rules:
        - Always include <thought> followed by either <action> or <final_answer> in each step.
        - After <action>, stop and wait for the actual <observation>. Do not generate <observation> yourself.
        - Use clear, concise reasoning in <thought> to justify the chosen action or final answer.

        Action format:
        - For tools without arguments: <action>tool_name</action>
        - For tools with arguments: <action>tool_name("arg1", "arg2")</action>
        - Enclose string arguments in double quotes and separate multiple arguments with commas.
        - Do not use key-value or other formats.

        Example:
        User: 
            <question>"What is the current time?"</question>
        Agent: 
            <thought>The user wants the current time. The get_current_time tool is appropriate.</thought>
            <action>get_current_time</action>
        User:
            <observation>04:15 PM NZST</observation>
        Agent: 
            <thought>The observation provides the time, which answers the question.</thought>
            <final_answer>The current time is 04:15 PM NZST.</final_answer>

        Available tools:
        \(toolList)

        Environment:
        - Operating System: iOS
        """
    }
}
