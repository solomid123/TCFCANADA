import XCTest

final class ExamFlowUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testHostedAutomaticConnectionWithoutServerSettings() async throws {
        let app = XCUIApplication()
        app.launchArguments = ["-test-ai-listening"]
        // No server URL, access token or session ID is supplied by the test.
        app.launchEnvironment = ["TCF_USE_HOSTED_LISTENING": "1"]
        app.launch()
        let connected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.buttons["start-ai-listening"].exists || app.buttons["ai-next"].exists || app.staticTexts["ai-result-score"].exists
        }, object: nil)
        let outcome = await XCTWaiter.fulfillment(of: [connected], timeout: 120)
        XCTAssertEqual(outcome, .completed)
        XCTAssertFalse(app.staticTexts["Configurez l'adresse du serveur dans Connexion."].exists)
        #if !DEBUG
        XCTAssertFalse(app.buttons["Connexion au serveur IA"].exists)
        #endif
        if app.buttons["start-ai-listening"].exists { app.buttons["start-ai-listening"].tap() }
        if app.buttons["ai-next"].exists {
            let play = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'ai-play-'")).firstMatch
            XCTAssertTrue(play.exists)
            play.tap()
            app.terminate()
            app.launch()
            XCTAssertTrue(app.buttons["ai-next"].waitForExistence(timeout: 15))
        }
    }

    @MainActor
    func testAIListeningDownloadsResumesAndReviewsAll39Questions() async throws {
        do {
            let (_, response) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:8766/health")!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.cannotConnectToHost) }
        } catch {
            throw XCTSkip("Start backend/tests/fixture_server.py on port 8766 to run the AI integration UI test (no Azure calls).")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-test-ai-listening"]
        app.launchEnvironment = ["TCF_BACKEND_URL": "http://127.0.0.1:8766", "TCF_BACKEND_TOKEN": "ui-test-token", "TCF_LISTENING_SESSION_ID": UUID().uuidString.lowercased()]
        app.launch()
        XCTAssertTrue(app.buttons["start-ai-listening"].waitForExistence(timeout: 45))
        app.buttons["start-ai-listening"].tap()
        XCTAssertFalse(app.buttons["ai-next"].isEnabled)
        XCTAssertFalse(app.staticTexts["À dix heures."].exists)
        XCTAssertFalse(app.staticTexts["Transcription"].exists)
        app.buttons["ai-play-1"].tap()
        app.buttons["ai-answer-0"].tap()
        app.buttons["ai-next"].tap()
        app.terminate()
        // The remaining session, including grading, must work with the token persisted in Keychain.
        app.launchEnvironment.removeValue(forKey: "TCF_BACKEND_TOKEN")
        app.launch()
        XCTAssertTrue(app.staticTexts["Question 2 sur 39"].waitForExistence(timeout: 10))
        app.buttons["ai-previous"].tap()
        XCTAssertTrue(app.buttons["ai-next"].isEnabled)
        app.buttons["ai-next"].tap()
        for _ in 2...39 {
            app.buttons["ai-answer-0"].tap()
            app.buttons["ai-next"].tap()
        }
        XCTAssertTrue(app.staticTexts["ai-result-score"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["ai-result-score"].label, "10 / 39")
        app.buttons["ai-review-1"].tap()
        XCTAssertTrue(app.staticTexts["Transcription"].exists)
        XCTAssertTrue(app.staticTexts["Pourquoi ?"].exists)
        app.buttons["ai-review-1"].tap()
        app.buttons["Erreurs (29)"].tap()
        XCTAssertFalse(app.buttons["ai-review-1"].exists)
        for _ in 0..<16 where !app.buttons["ai-review-39"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["ai-review-39"].isHittable)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["ai-result-score"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testPracticeRetainsAnswersAndShowsResults() {
        let app = XCUIApplication()
        app.launchArguments = ["-test-reading-session"]
        app.launch()
        XCTAssertTrue(app.buttons["answer-0"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["next-question"].isEnabled)
        XCTAssertFalse(app.buttons["Examen"].exists)
        app.buttons["answer-0"].tap()
        app.buttons["next-question"].tap()
        app.buttons["previous-question"].tap()
        XCTAssertFalse(app.buttons["answer-0"].isEnabled)
        XCTAssertTrue(app.buttons["next-question"].isEnabled)
        app.buttons["next-question"].tap()
        app.buttons["answer-0"].tap()
        app.buttons["next-question"].tap()
        XCTAssertTrue(app.staticTexts["Série terminée"].waitForExistence(timeout: 5))
        app.buttons["Recommencer"].tap()
        XCTAssertTrue(app.buttons["answer-0"].isEnabled)
        XCTAssertFalse(app.buttons["next-question"].isEnabled)
    }

    @MainActor
    func testLevelFilterAndFocusedPractice() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Filtrer les séries : tous les niveaux"].tap()
        app.buttons["Niveau B2"].tap()
        XCTAssertTrue(app.buttons["read_b2"].exists)
        XCTAssertFalse(app.buttons["read_a1_a2"].exists)
        app.buttons["read_b2"].tap()
        XCTAssertTrue(app.buttons["answer-0"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Examen"].exists)
        app.buttons["Pratiques"].tap()
        XCTAssertTrue(app.buttons["Examen"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWritingOpensSelectedTaskAndRetainsDrafts() {
        let app = XCUIApplication()
        app.launchArguments = ["-test-writing-list"]
        app.launch()
        app.buttons["write_t2"].tap()
        XCTAssertTrue(app.staticTexts["Tâche 2 : Récit d'une expérience marquante"].exists)
        let editor = app.textViews["writing-draft"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Mon brouillon pour la deuxieme tache.")
        app.swipeDown()
        app.buttons["Tâche 1"].tap()
        XCTAssertEqual(editor.value as? String, "")
        app.buttons["Tâche 2"].tap()
        XCTAssertEqual(editor.value as? String, "Mon brouillon pour la deuxieme tache.")
    }

    @MainActor
    func testExamAdvancesThroughAllFourSections() {
        let app = XCUIApplication()
        app.launchArguments = ["-test-exam"]
        app.launch()
        app.swipeUp()
        app.buttons["start-exam"].tap()
        XCTAssertTrue(app.buttons["answer-0"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Scores"].exists)
        for _ in 0..<6 {
            app.buttons["answer-0"].tap()
            // Exam answers remain editable; correctness is not revealed.
            XCTAssertTrue(app.buttons["answer-0"].isEnabled)
            app.buttons["next-question"].tap()
        }
        XCTAssertTrue(app.buttons["next-section"].waitForExistence(timeout: 5))
        app.buttons["next-section"].tap()
        XCTAssertFalse(app.buttons["Transcription"].exists)
        for _ in 0..<10 {
            app.buttons["answer-0"].tap()
            app.buttons["next-question"].tap()
        }
        app.buttons["next-section"].tap()
        XCTAssertTrue(app.textViews["writing-draft"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Modèle NCLC 7"].exists)
        app.buttons["finish-section"].tap()
        app.buttons["next-section"].tap()
        XCTAssertTrue(app.buttons["Enregistrer la réponse"].waitForExistence(timeout: 5))
        app.buttons["finish-section"].tap()
        XCTAssertTrue(app.staticTexts["Session terminée."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Scores"].exists)
    }
}
