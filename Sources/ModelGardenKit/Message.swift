import Foundation
import Observation

@Observable
public final class Message: Identifiable, @unchecked Sendable {
    public let id = UUID()
    public let role: Role
    public var content: String
    public var images: [URL]
    public var videos: [URL]
    public let timestamp: Date

    public init(role: Role, content: String, images: [URL] = [], videos: [URL] = []) {
        self.role = role
        self.content = content
        self.images = images
        self.videos = videos
        self.timestamp = .now
    }

    public enum Role: Sendable { case user, assistant, system }
}

public extension Message {
    static func user(_ content: String, images: [URL] = [], videos: [URL] = []) -> Message {
        Message(role: .user, content: content, images: images, videos: videos)
    }
    static func assistant(_ content: String) -> Message { Message(role: .assistant, content: content) }
    static func system(_ content: String) -> Message { Message(role: .system, content: content) }
}
