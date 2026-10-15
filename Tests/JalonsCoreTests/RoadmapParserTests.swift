import Testing
@testable import JalonsCore

@Suite struct RoadmapParserTests {
    @Test func readsTheTitleAndOnlyThePhaseBoxes() {
        let parsed = RoadmapParser.parse(Samples.spec)
        #expect(parsed.title == "Projet d'essai : conception")
        #expect(parsed.entries.map(\.number) == [1, 2, 3])
        #expect(parsed.entries.map(\.title) == ["socle", "inventaire", "noms"])
        #expect(parsed.entries.map(\.isChecked) == [true, false, false])
        #expect(parsed.entries.first?.line == 9)
    }

    @Test func acceptsTheUsualSeparatorsAndListMarkers() {
        let parsed = RoadmapParser.parse("""
        - [ ] Phase 1 — socle
        * [X] Phase 2: inventaire
        1. [ ] phase 3 - noms
        + [x] PHASE 4
        """)
        #expect(parsed.entries.map(\.number) == [1, 2, 3, 4])
        #expect(parsed.entries.map(\.title) == ["socle", "inventaire", "noms", ""])
        #expect(parsed.entries.map(\.isChecked) == [false, true, false, true])
    }

    @Test func ignoresCodeBlocksAndKeepsTheFirstOfTwoEqualNumbers() {
        let parsed = RoadmapParser.parse("""
        ```markdown
        - [x] Phase 9 : dans un bloc de code
        ```
        - [ ] Phase 1 : **socle**
        - [x] Phase 1 : doublon
        ~~~
        - [ ] Phase 8 : autre bloc
        ~~~
        """)
        #expect(parsed.entries.count == 1)
        #expect(parsed.entries.first?.title == "socle")
        #expect(parsed.entries.first?.isChecked == false)
    }

    @Test func aTextWithoutPhaseBoxesHasNoEntries() {
        let parsed = RoadmapParser.parse("# Titre\n\n- [ ] Faire quelque chose\n- [x] Phasage : non\n")
        #expect(parsed.entries.isEmpty)
        #expect(parsed.title == "Titre")
    }

    @Test func formattingAroundTheLabelIsIgnored() {
        let parsed = RoadmapParser.parse("""
        - [ ] **Phase 1 : socle**
        - [x] **Phase 2** : inventaire
        - [ ] [Phase 3 : noms](plans/noms.md)
        - [ ] `Phase 4` : scènes
        """)
        #expect(parsed.entries.map(\.number) == [1, 2, 3, 4])
        #expect(parsed.entries.map(\.title) == ["socle", "inventaire", "noms", "scènes"])
        #expect(parsed.entries.map(\.isChecked) == [false, true, false, false])
        #expect(parsed.ignoredLines.isEmpty)
    }

    @Test func subPhasesAndDuplicatesAreNotedNotLost() {
        let parsed = RoadmapParser.parse("""
        - [ ] Phase 1 : socle
        - [ ] Phase 1.1 : sous-étape
        - [x] Phase 1 : doublon
        - [ ] Phase 12.3 : autre sous-étape
        - [ ] Phasage : pas une phase
        """)
        #expect(parsed.entries.map(\.number) == [1])
        #expect(parsed.ignoredLines == [2, 3, 4])
    }

    @Test func htmlCommentsAndFrontMatterAreSkipped() {
        let parsed = RoadmapParser.parse("""
        ---
        title: # pas le titre
        ---
        # Le vrai titre
        <!-- - [ ] Phase 7 : en commentaire -->
        <!--
        - [ ] Phase 8 : commentaire sur plusieurs lignes
        -->
        - [ ] Phase 1 : socle <!-- note -->
        """)
        #expect(parsed.title == "Le vrai titre")
        #expect(parsed.entries.map(\.number) == [1])
        #expect(parsed.entries.first?.title == "socle")
    }

    @Test func fencesFollowTheCommonMarkRules() {
        let parsed = RoadmapParser.parse("""
        ```code``` texte qui n'ouvre pas de bloc
        - [ ] Phase 1 : socle
        ````
        ```
        - [ ] Phase 9 : toujours dans le bloc
        ````
        - [x] Phase 2 : inventaire
        """)
        #expect(parsed.entries.map(\.number) == [1, 2])
    }

    @Test func windowsLineEndingsAreRead() {
        let parsed = RoadmapParser.parse("# Titre\r\n- [ ] Phase 1 : a\r\n- [x] Phase 2 : b\r\n")
        #expect(parsed.title == "Titre")
        #expect(parsed.entries.map(\.isChecked) == [false, true])
    }

    @Test func anOrphanCommentInsideALineSwallowsNothing() {
        let parsed = RoadmapParser.parse("""
        - [ ] Phase 1 : retirer les `<!--` orphelins
        - [ ] Phase 2 : b
        <!-->
        <!--->
        - [ ] Phase 3 : c
        """)
        #expect(parsed.entries.map(\.number) == [1, 2, 3])
        #expect(parsed.entries.first?.title == "retirer les <!-- orphelins")
        #expect(parsed.unclosedCommentLine == nil)
    }

    @Test func aCommentNeverClosedIsReportedWithItsOpeningLine() {
        let parsed = RoadmapParser.parse("""
        - [ ] Phase 1 : a
        <!-- commentaire jamais refermé
        - [ ] Phase 2 : b
        """)
        #expect(parsed.entries.map(\.number) == [1])
        #expect(parsed.unclosedCommentLine == 2)
    }

    @Test func anUnclosedFrontMatterIsNotOneAndABoxInsideAClosedOneIsNoted() {
        let separator = RoadmapParser.parse("---\n# Titre\n- [ ] Phase 1 : a\n")
        #expect(separator.title == "Titre")
        #expect(separator.entries.map(\.number) == [1])
        let header = RoadmapParser.parse("---\n- [ ] Phase 9 : x\n---\n- [ ] Phase 1 : a\n")
        #expect(header.entries.map(\.number) == [1])
        #expect(header.ignoredLines == [2])
    }

    @Test func moreLabelFormsAreReadAndOrdinaryBoxesAreNotFlagged() {
        let parsed = RoadmapParser.parse("""
        - [ ] Phase1 : a
        - [ ] Phase_2 : b
        - [ ] *Phase 3* : c
        - [ ] ~~Phase 4~~ : d
        - [ ] [Phase 5][p] : e
        - [ ] ✅ Phase 6 : f
        - [x] Phase de recette validée
        """)
        #expect(parsed.entries.map(\.number) == [1, 2, 3, 4, 5, 6])
        #expect(parsed.entries.map(\.title) == ["a", "b", "c", "d", "e", "f"])
        #expect(parsed.ignoredLines.isEmpty)
    }
}
