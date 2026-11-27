import AppKit
import Foundation
import Testing
@testable import Jalons

/// Les fichiers que le système ouvre dans Jalons arrivent parfois avant que l'app soit prête (Jalons lancée par
/// `open -a`) : ils attendent, puis arrivent une seule fois.
@MainActor @Suite struct SpecInboxTests {
    let a = URL(fileURLWithPath: "/tmp/projet/a.md")
    let b = URL(fileURLWithPath: "/tmp/projet/b.md")

    final class Received { var batches: [[URL]] = [] }

    @Test func filesReceivedBeforeTheAppIsReadyWaitForIt() {
        let inbox = SpecInbox()
        let received = Received()
        inbox.receive([a])
        inbox.receive([b])
        #expect(received.batches.isEmpty)
        inbox.receiver = { received.batches.append($0) }
        #expect(received.batches == [[a, b]])
    }

    /// Le délégué de l'app passe à la boîte partagée ce que le système lui ouvre.
    @Test func theAppDelegateHandsOpenedFilesToTheSharedInbox() {
        let received = Received()
        SpecInbox.shared.receiver = { received.batches.append($0) }
        defer { SpecInbox.shared.receiver = nil }
        AppDelegate().application(NSApplication.shared, open: [a, b])
        #expect(received.batches == [[a, b]])
    }

    @Test func filesReceivedOnceReadyArriveRightAway() {
        let inbox = SpecInbox()
        let received = Received()
        inbox.receiver = { received.batches.append($0) }
        inbox.receive([a])
        inbox.receive([b])
        #expect(received.batches == [[a], [b]])
    }

    @Test func waitingFilesArriveOnlyOnce() {
        let inbox = SpecInbox()
        let first = Received()
        let second = Received()
        inbox.receive([a])
        inbox.receiver = { first.batches.append($0) }
        inbox.receiver = { second.batches.append($0) }
        #expect(first.batches == [[a]])
        #expect(second.batches.isEmpty)
    }
}
