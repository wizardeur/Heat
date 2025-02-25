import Foundation
import SharedKit
import GenKit

public struct TitleTool {
    
    public struct Arguments: Codable {
        public var title: String?
    }
    
    public static let function = Tool.Function(
        name: "title_maker",
        description: """
            Return a title if there is a clear topic of conversation. The title should be under 4 words.
            Nothing is returned if there is no topic or if the conversation is just greetings.
            """,
        parameters: .init(
            type: .object,
            properties: [
                "title": .init(
                    type: .string,
                    description: "A short title"
                )
            ]
        )
    )
    
    public static let message = Message(
        role: .user,
        content: "Provide a title for this conversation. Use the `\(function.name)` tool in your response."
    )
}

extension TitleTool.Arguments {
    
    public init(_ arguments: String) throws {
        guard let data = arguments.data(using: .utf8) else {
            throw ToolboxError.failedDecoding
        }
        self = try JSONDecoder().decode(Self.self, from: data)
    }
}
