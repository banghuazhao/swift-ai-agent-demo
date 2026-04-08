//
// Created by Banghua Zhao on 26/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import Combine
import SwiftUI

@MainActor
@Observable
class ContentViewModel {
    private let agentService: AgentService
    private var cancellables = Set<AnyCancellable>()

    // UI State
    var userInput: String = ""
    var steps: [AgentStep] = []
    var isRunning: Bool = false
    var errorMessage: String?

    init(
        agentService: AgentService = AgentService()
    ) {
        self.agentService = agentService

        // Observe agent service changes
        agentService.$steps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSteps in
                self?.steps = newSteps
            }
            .store(in: &cancellables)
    }

    func startAgent() async {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a question or task."
            return
        }

        errorMessage = nil

        isRunning = true
        defer { isRunning = false }
        
        await agentService.runAgent(with: userInput)
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
