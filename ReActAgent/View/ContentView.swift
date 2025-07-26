//
// Created by Banghua Zhao on 26/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State var model = ContentViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header section with input
                VStack(spacing: 16) {
                    Text("ReAct Agent")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Ask me anything and watch how I think and act!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Input section
                    VStack(spacing: 12) {
                        TextField("Enter your question or task...", text: $model.userInput, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                        
                        HStack {
                            Button("Clear") {
                                model.clearSteps()
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isRunning)
                            
                            Spacer()
                            
                            Button {
                                model.startAgent()
                            } label: {
                                if model.isRunning {
                                    HStack {
                                        ProgressView()
                                        Text("Agent is thinking...")
                                    }
                                } else {
                                    Text("Start Agent")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isRunning || model.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    
                    // Error message
                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
                .padding()
                
                // Steps section
                if !model.steps.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(model.steps) { step in
                                    StepView(step: step, model: model)
                                        .id(step.id)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: model.steps.count) { _, _ in
                            if let lastStep = model.steps.last {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo(lastStep.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Ready to help!")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Enter a question above to see the ReAct agent in action.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct StepView: View {
    let step: AgentStep
    let model: ContentViewModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step icon
            ZStack {
                Circle()
                    .fill(model.getStepColor(step.type).opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: model.getStepIcon(step.type))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(model.getStepColor(step.type))
            }
            
            // Step content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(model.getStepTitle(step.type))
                        .font(.headline)
                        .foregroundColor(model.getStepColor(step.type))
                    
                    Spacer()
                    
                    Text(formatTime(step.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(step.content)
                    .lineLimit(step.type == .action ? 5 : 10)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if step.type == .finalAnswer {
                    Divider()
                        .background(model.getStepColor(step.type))
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(model.getStepColor(step.type).opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
