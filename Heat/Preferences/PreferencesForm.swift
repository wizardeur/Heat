import SwiftUI
import SharedKit
import GenKit
import HeatKit

struct PreferencesForm: View {
    @Environment(AppState.self) var state
    @Environment(\.dismiss) private var dismiss

    @State var preferences: Preferences

    @State private var showingDeleteConfirmation = false
    @State private var showingAdditionalServices = false

    var body: some View {
        Form {
            Section {
                NavigationLink("Memories") {
                    MemoryList()
                }

                Toggle("Response Streaming", isOn: $preferences.shouldStream)

                Picker("Text Rendering", selection: $preferences.textRendering) {
                    ForEach(Preferences.TextRendering.allCases, id: \.self) {
                        Text($0.rawValue.capitalized).tag($0)
                    }
                }

                Picker("Default Assistant", selection: $preferences.defaultAssistantID) {
                    Text("None").tag(String?.none)
                    Divider()
                    ForEach(state.agentsProvider.agents.filter { $0.kind == .assistant }) { agent in
                        Text(agent.name).tag(agent.id)
                    }
                }
            } header: {
                Text("Experience")
            }

            Section {
                Picker("Chats", selection: $preferences.preferred.chatServiceID) {
                    servicePickerView(\.supportsChats)
                }
                Picker("Images", selection: $preferences.preferred.imageServiceID) {
                    servicePickerView(\.supportsImages)
                }
                Picker("Summarization", selection: $preferences.preferred.summarizationServiceID) {
                    servicePickerView(\.supportsSummarization)
                }

                if showingAdditionalServices {
                    Picker("Embeddings", selection: $preferences.preferred.embeddingServiceID) {
                        servicePickerView(\.supportsEmbeddings)
                    }
                    Picker("Transcriptions", selection: $preferences.preferred.transcriptionServiceID) {
                        servicePickerView(\.supportsTranscriptions)
                    }
                    Picker("Speech", selection: $preferences.preferred.speechServiceID) {
                        servicePickerView(\.supportsSpeech)
                    }
                } else {
                    Button {
                        showingAdditionalServices = true
                    } label: {
                        Text("Additional services")
                    }
                    #if os(macOS)
                    .buttonStyle(.link)
                    #endif
                }

            } header: {
                Text("Preferred Services")
            } footer: {
                Text("These are the services used when you start a new conversation.")
            }

            Section {
                NavigationLink("Services") {
                    ServiceList()
                }
                NavigationLink("Agents") {
                    AgentList()
                }
                NavigationLink("Permissions") {
                    PermissionsList()
                }
            } header: {
                Text("Advanced")
            } footer: {
                Text("Configure services, prompt agents and third-party permissions.")
            }

            Section {
                Toggle("Debug", isOn: $preferences.debug)
            } footer: {
                Text("Displays additional debug output throughout the app.")
            }

            Section {
                Button("Reset Agents", action: handleAgentReset)
                Button("Reset Conversations", action: handleConversationReset)
                Button("Reset Preferences", action: handlePreferencesReset)
            }
            #if os(macOS)
            .buttonStyle(.link)
            #endif

            Section {
                Button("Delete All Data", role: .destructive, action: { showingDeleteConfirmation = true })
            }
            #if os(macOS)
            .buttonStyle(.link)
            #endif
        }
        .navigationTitle("Preferences")
        .appFormStyle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: handleSave)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: dismiss.callAsFunction)
            }
        }
        .alert("Are you sure?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive, action: handleDeleteAll)
        } message: {
            Text("This will delete all app data and preferences.")
        }
    }

    func servicePickerView(_ prop: KeyPath<Service, Bool>) -> some View {
        Group {
            Text("None").tag(String?.none)
            Divider()
            ForEach(state.preferencesProvider.services.filter { $0[keyPath: prop] }) { service in
                Text(service.name).tag(service.id)
            }
        }
    }

    func handleAgentReset() {
        Task {
            try await state.agentsProvider.reset()
        }
    }

    func handleConversationReset() {
        Task {
            try await state.conversationsProvider.reset()
            try await state.messagesProvider.reset()
        }
    }

    func handlePreferencesReset() {
        Task {
            try await state.preferencesProvider.reset()

            // Restablish preferences in the form
            preferences = state.preferencesProvider.preferences
        }
    }

    func handleDeleteAll() {
        handleAgentReset()
        handleConversationReset()
        handlePreferencesReset()
    }

    func handleSave() {
        Task {
            try await state.preferencesProvider.upsert(preferences)
            dismiss()
        }
    }
}

enum PreferencesError: LocalizedError {
    case missingID
    case missingName
    case unsavedChanges

    var errorDescription: String? {
        switch self {
        case .missingID: "Missing ID"
        case .missingName: "Missing name"
        case .unsavedChanges: "Unsaved changes"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .missingID: "Enter an identifier for the service."
        case .missingName: "Enter a name for the service."
        case .unsavedChanges: "You have unsaved changes, do you want to discard them?"
        }
    }
}
