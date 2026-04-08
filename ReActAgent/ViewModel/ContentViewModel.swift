//
// Created by Banghua Zhao on 26/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

@MainActor
@Observable
class ContentViewModel {
    private let agentService: AgentService

    // UI State
    var userInput: String = ""
    var steps: [AgentStep] = []
    var isRunning: Bool = false
    var errorMessage: String?
    let suggestedQuestions: [String] = [
        "Get the current time, wait a moment, then get the time again and create a file called 'time_comparison.txt' with both timestamps",
        "Calculate 50 * 2, then add 25 to the result, then divide by 5, and save the final answer to 'complex_math.txt'",
        "Create file 'step1.txt' with 'Hello', then create 'step2.txt' with 'World', then read both files and create 'combined.txt' with their contents"
    ]

    init(
        agentService: AgentService = AgentService()
    ) {
        self.agentService = agentService
    }

    func startAgent() async {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a question or task."
            return
        }

        errorMessage = nil
        steps.removeAll()

        isRunning = true
        defer { isRunning = false }
        
        let stepStream = agentService.runAgent(with: userInput)
        for await step in stepStream {
            steps.append(step)
        }
    }

    func clearSteps() {
        steps.removeAll()
        errorMessage = nil
        userInput = ""
    }

    func getStepIcon(_ type: AgentStep.StepType) -> String {
        switch type {
        case .thought:
            return "brain.head.profile"
        case .action:
            return "gearshape"
        case .observation:
            return "eye"
        case .finalAnswer:
            return "checkmark.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    func getStepColor(_ type: AgentStep.StepType) -> Color {
        switch type {
        case .thought:
            return .blue
        case .action:
            return .orange
        case .observation:
            return .green
        case .finalAnswer:
            return .purple
        case .error:
            return .red
        }
    }

    func getStepTitle(_ type: AgentStep.StepType) -> String {
        switch type {
        case .thought:
            return "💭 Thought"
        case .action:
            return "🔧 Action"
        case .observation:
            return "🔍 Observation"
        case .finalAnswer:
            return "✅ Final Answer"
        case .error:
            return "❌ Error"
        }
    }
}
