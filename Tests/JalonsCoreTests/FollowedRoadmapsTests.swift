import Foundation
import Testing
@testable import JalonsCore

@Suite struct FollowedRoadmapsTests {
    @Test func theFirstAddedIsPrimaryAndEveryAddedFriseIsShown() {
        var followed = FollowedRoadmaps()
        let addedA = followed.add("/a.md")
        let addedB = followed.add("/b.md")
        let addedAgain = followed.add("/a.md")
        #expect(addedA && addedB && !addedAgain)
        #expect(followed.paths == ["/a.md", "/b.md"])
        #expect(followed.primary == "/a.md")
        #expect(followed.visible == ["/a.md", "/b.md"])
    }

    @Test func removingThePrimaryHandsItToTheFirstRemaining() {
        var followed = FollowedRoadmaps()
        followed.add("/a.md")
        followed.add("/b.md")
        followed.add("/c.md")
        followed.setPrimary("/c.md")
        followed.remove("/c.md")
        #expect(followed.primary == "/a.md")
        #expect(followed.paths == ["/a.md", "/b.md"])
        #expect(!followed.visible.contains("/c.md"))
        followed.remove("/a.md")
        followed.remove("/b.md")
        #expect(followed.primary == nil && followed.paths.isEmpty)
    }

    @Test func primaryAndVisibilityIgnoreUnknownPaths() {
        var followed = FollowedRoadmaps()
        followed.add("/a.md")
        followed.setPrimary("/x.md")
        followed.setVisible("/x.md", true)
        followed.setVisible("/a.md", false)
        #expect(followed.primary == "/a.md")
        #expect(followed.visible.isEmpty)
    }

    @Test func replacingKeepsPlacePrimaryAndVisibility() {
        var followed = FollowedRoadmaps()
        followed.add("/a.md")
        followed.add("/b.md")
        followed.setVisible("/a.md", false)
        followed.replace("/a.md", with: "/n.md")
        #expect(followed.paths == ["/n.md", "/b.md"])
        #expect(followed.primary == "/n.md")
        #expect(followed.visible == ["/b.md"])
        // Remplacer par une spec déjà suivie revient à retirer l'ancienne.
        followed.replace("/n.md", with: "/b.md")
        #expect(followed.paths == ["/b.md"])
        #expect(followed.primary == "/b.md")
    }

    @Test func unknownOrIdenticalPathsChangeNothing() {
        var followed = FollowedRoadmaps()
        followed.add("/a.md")
        let before = followed
        followed.remove("/x.md")
        followed.replace("/x.md", with: "/y.md")
        followed.replace("/a.md", with: "/a.md")
        #expect(followed == before)
    }

    @Test func replacingByAnAlreadyFollowedSpecKeepsItsOwnVisibility() {
        var followed = FollowedRoadmaps()
        followed.add("/a.md")
        followed.add("/b.md")
        followed.setVisible("/a.md", false)
        followed.replace("/a.md", with: "/b.md")
        #expect(followed.paths == ["/b.md"] && followed.visible == ["/b.md"] && followed.primary == "/b.md")
    }

    @Test func aListWithoutVisibilityShowsNoFrise() throws {
        let decoded = try JSONDecoder().decode(FollowedRoadmaps.self, from: Data(#"{"paths":["/a.md"]}"#.utf8))
        #expect(decoded.paths == ["/a.md"] && decoded.visible.isEmpty && decoded.primary == "/a.md")
    }

    @Test func theSingleSpecSettingIsCarriedOver() {
        let shown = FollowedRoadmaps(legacyPath: "/a.md", legacyVisible: true)
        #expect(shown.paths == ["/a.md"] && shown.primary == "/a.md" && shown.visible == ["/a.md"])
        let hidden = FollowedRoadmaps(legacyPath: "/a.md", legacyVisible: false)
        #expect(hidden.visible.isEmpty)
        #expect(FollowedRoadmaps(legacyPath: nil, legacyVisible: true) == FollowedRoadmaps())
    }

    @Test func survivesARoundTripThroughJSON() throws {
        var followed = FollowedRoadmaps()
        followed.add("/a.md")
        followed.add("/b.md")
        followed.setPrimary("/b.md")
        followed.setVisible("/a.md", false)
        let decoded = try JSONDecoder().decode(FollowedRoadmaps.self, from: JSONEncoder().encode(followed))
        #expect(decoded == followed)
    }

    @Test func aDamagedListIsRepaired() throws {
        let json = #"{"paths":["/a.md","/a.md","/b.md"],"primary":"/z.md","visible":["/b.md","/z.md"]}"#
        let decoded = try JSONDecoder().decode(FollowedRoadmaps.self, from: Data(json.utf8))
        #expect(decoded.paths == ["/a.md", "/b.md"])
        #expect(decoded.primary == "/a.md")
        #expect(decoded.visible == ["/b.md"])
    }
}
