// A conversation is an interaction between the user and a large language model (LLM). It has a title that helps
// set context for what the conversation is generally about and it has a history or messages.

import Foundation
import GenKit
import SharedKit

public struct Conversation: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var picture: Asset?
    public var messages: [Message]
    public var suggestions: [String]
    public var tools: Set<Tool>
    public var state: State
    public var created: Date
    public var modified: Date
    
    public enum State: Codable, Sendable {
        case processing
        case streaming
        case suggesting
        case none
    }
    
    public init(id: String = .id, title: String = "New Conversation", subtitle: String? = nil, picture: Asset? = nil,
                messages: [Message] = [], suggestions: [String] = [], tools: Set<Tool> = [], state: State = .none) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.picture = picture
        self.messages = messages
        self.suggestions = suggestions
        self.tools = tools
        self.state = state
        self.created = .now
        self.modified = .now
    }
    
    public static var empty: Self {
        .init()
    }
    
    mutating func apply(conversation: Conversation) {
        self.title = conversation.title
        self.subtitle = conversation.subtitle
        self.picture = conversation.picture
        self.messages = conversation.messages
        self.suggestions = conversation.suggestions
        self.tools = conversation.tools
        self.state = conversation.state
        self.modified = .now
    }
}

actor ConversationStore {
    private var conversations: [Conversation] = []
    
    func save(_ conversations: [Conversation]) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        
        let data = try encoder.encode(conversations)
        try data.write(to: self.dataURL, options: [.atomic])
        self.conversations = conversations
    }
    
    func load() throws -> [Conversation] {
        let data = try Data(contentsOf: dataURL)
        let decoder = PropertyListDecoder()
        conversations = try decoder.decode([Conversation].self, from: data)
        return conversations
    }
    
    private var dataURL: URL {
        get throws {
            try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                    .appendingPathComponent("ConversationData.plist")
        }
    }
}

@MainActor
@Observable
public final class ConversationProvider {
    public static let shared = ConversationProvider()
    
    public private(set) var conversations: [Conversation] = []
    
    public func get(_ id: String) throws -> Conversation {
        guard let conversation = conversations.first(where: { $0.id == id }) else {
            throw ConversationProviderError.notFound
        }
        return conversation
    }
    
    public func get(messageID: String, conversationID: String) throws -> Message {
        let conversation = try get(conversationID)
        guard let message = conversation.messages.first(where: { $0.id == messageID }) else {
            throw ConversationProviderError.messageNotFound
        }
        return message
    }
    
    public func create(instructions: [Message], tools: Set<Tool>, state: Conversation.State = .none) async throws -> Conversation {
        let conversation = Conversation(messages: instructions, tools: tools, state: state)
        try await upsert(conversation)
        return conversation
    }
    
    public func upsert(_ conversation: Conversation) async throws {
        var conversations = self.conversations
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            var existing = conversations[index]
            existing.apply(conversation: conversation)
            conversations[index] = existing
        } else {
            conversations.insert(conversation, at: 0)
        }
        self.conversations = conversations
        try await save()
    }
    
    public func upsert(messages: [Message], conversationID: String) async throws {
        for message in messages {
            try await upsert(message: message, conversationID: conversationID)
        }
    }
    
    public func upsert(message: Message, conversationID: String) async throws {
        var conversation = try get(conversationID)
        if let index = conversation.messages.firstIndex(where: { $0.id == message.id }) {
            conversation.messages[index] = message
        } else {
            conversation.messages.append(message)
        }
        try await upsert(conversation)
    }
    
    public func upsert(title: String, conversationID: String) async throws {
        var conversation = try get(conversationID)
        conversation.title = title
        try await upsert(conversation)
    }
    
    public func upsert(suggestions: [String], conversationID: String) async throws {
        var conversation = try get(conversationID)
        conversation.suggestions = suggestions
        try await upsert(conversation)
    }
    
    public func upsert(state: Conversation.State, conversationID: String) async throws {
        var conversation = try get(conversationID)
        conversation.state = state
        try await upsert(conversation)
    }
    
    public func delete(_ id: String) async throws {
        let conversation = try get(id)
        conversations.removeAll(where: { conversation == $0 })
        try await save()
    }
    
    // MARK: - Private
    
    private let data = ConversationStore()
    
    private init() {
        Task { try await load() }
    }
    
    private func load() async throws {
        self.conversations = try await data.load()
    }
    
    private func save() async throws {
        try await data.save(conversations)
    }
}

public enum ConversationProviderError: Error {
    case notFound
    case messageNotFound
}
