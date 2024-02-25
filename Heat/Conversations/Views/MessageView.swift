import SwiftUI
import GenKit
import HeatKit
import MarkdownUI
import Splash

struct MessageView: View {
    let message: Message
    
    var body: some View {
        if message.content != nil {
            MessageViewText(message: message, finishReason: message.finishReason)
                .messageStyle(message)
                .messageSpacing(message)
                .messageAttachments(message)
        }
    }
}

struct MessageViewText: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let message: Message
    let finishReason: Message.FinishReason?
    
    var body: some View {
        if message.role == .user {
            Text(message.content ?? "")
                .textSelection(.enabled)
        } else {
            Markdown(message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                .markdownTheme(.mate)
                .markdownCodeSyntaxHighlighter(.splash(theme: .sunset(withFont: .init(size: monospaceFontSize))))
                .textSelection(.enabled)
        }
    }
    
    #if os(macOS)
    var monospaceFontSize: CGFloat = 11
    #else
    var monospaceFontSize: CGFloat = 12
    #endif
}

// Modifiers

struct MessageViewStyle: ViewModifier {
    let message: Message
    
    func body(content: Content) -> some View {
        switch message.role {
        case .system, .tool:
            content
                .font(.footnote)
                .lineSpacing(2)
                .foregroundStyle(.secondary)
        case .assistant:
            content
                .font(.body)
                .lineSpacing(2)
        case .user:
            content
                .font(.body)
                .lineSpacing(2)
        }
    }
}

struct MessageViewSpacing: ViewModifier {
    let message: Message
        
    func body(content: Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            switch message.role {
            case .system, .tool:
                content
            case .assistant:
                Image(systemName: "smallcircle.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(assistantSymbolColor)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Assistant")
                            .font(roleFont)
                            .lineSpacing(2)
                            .opacity(roleOpacity)
                        Spacer()
                    }
                    content
                }
            case .user:
                Image(systemName: "person.crop.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(userSymbolColor)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("You")
                            .font(roleFont)
                            .lineSpacing(2)
                            .opacity(roleOpacity)
                        Spacer()
                    }
                    content
                }
            }
        }
    }
    
    #if os(macOS)
    var roleFont = Font.body
    var roleOpacity = 0.5
    var roleSymbolOpacity = 0.5
    #else
    var roleFont = Font.system(size: 14)
    var roleOpacity = 0.3
    var userSymbolColor = Color.primary.opacity(0.3)
    var assistantSymbolColor = Color.indigo
    #endif
}

struct MessageViewAttachments: ViewModifier {
    let message: Message
        
    func body(content: Content) -> some View {
        if message.attachments.isEmpty {
            content
        } else {
            VStack {
                HStack {
                    if message.role == .user { Spacer() }
                    ForEach(message.attachments.indices, id: \.self) { index in
                        switch message.attachments[index] {
                        case .agent(let agentID):
                            Text(agentID)
                        case .asset(let asset):
                            PictureView(asset: asset)
                                .frame(width: 200, height: 200)
                                .clipShape(.rect(cornerRadius: 10))
                        default:
                            EmptyView()
                        }
                    }
                    if message.role == .assistant { Spacer() }
                }
                content
            }
        }
    }
}

extension View {
    
    func messageStyle(_ message: Message) -> some View {
        self.modifier(MessageViewStyle(message: message))
    }
    
    func messageSpacing(_ message: Message) -> some View {
        self.modifier(MessageViewSpacing(message: message))
    }
    
    func messageAttachments(_ message: Message) -> some View {
        self.modifier(MessageViewAttachments(message: message))
    }
}
