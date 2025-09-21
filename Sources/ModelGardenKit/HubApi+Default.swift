import Foundation
@preconcurrency import Hub

public extension HubApi {
    static var `default`: HubApi {
        #if os(macOS)
        return HubApi(downloadBase: URL.downloadsDirectory.appending(path: "huggingface"))
        #else
        return HubApi(downloadBase: URL.cachesDirectory.appending(path: "huggingface"))
        #endif
    }
}
