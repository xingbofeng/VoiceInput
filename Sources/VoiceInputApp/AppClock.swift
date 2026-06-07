import Foundation

protocol AppClock: Sendable {
    var now: Date { get }
    func sleep(nanoseconds: UInt64) async throws
}

struct SystemClock: AppClock {
    var now: Date {
        Date()
    }

    func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
