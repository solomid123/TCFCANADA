import XCTest

final class ExamFlowUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testCompletedListeningTestReopensFromQuestionBank() async throws {
        let app = XCUIApplication()
        app.launchArguments = ["-test-ai-listening"]
        app.launchEnvironment = ["TCF_USE_HOSTED_LISTENING": "1"]
        app.launch()
        let connected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.buttons["start-ai-listening"].exists || app.buttons["ai-next"].exists || app.staticTexts["ai-result-score"].exists
        }, object: nil)
        let connection = await XCTWaiter.fulfillment(of: [connected], timeout: 120)
        XCTAssertEqual(connection, .completed)
        XCTAssertFalse(app.staticTexts["ÉCOUTE IA"].exists)
        if app.buttons["start-ai-listening"].exists { app.buttons["start-ai-listening"].tap() }
        for _ in 0..<39 where app.buttons["ai-next"].exists {
            app.buttons["ai-answer-0"].tap()
            let finishing = app.buttons["ai-next"].label.contains("Terminer")
            app.buttons["ai-next"].tap()
            if finishing { break }
        }
        XCTAssertTrue(app.staticTexts["ai-result-score"].waitForExistence(timeout: 15))
        let score = app.staticTexts["ai-result-score"].label
        app.buttons["open-saved-listening-tests"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'saved-listening-'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 20))
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Terminé'"), object: saved)
        let savedResult = await XCTWaiter.fulfillment(of: [completed], timeout: 20)
        XCTAssertEqual(savedResult, .completed)
        for _ in 0..<4 where !saved.isHittable { app.swipeUp() }
        XCTAssertTrue(saved.label.contains("Terminé"))
        saved.tap()
        XCTAssertTrue(app.staticTexts["ai-result-score"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["ai-result-score"].label, score)
        app.terminate()
        app.launchArguments = ["-test-listening-library"]
        app.launch()
        let reopened = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'saved-listening-'")).firstMatch
        XCTAssertTrue(reopened.waitForExistence(timeout: 20))
        for _ in 0..<4 where !reopened.isHittable { app.swipeUp() }
        reopened.tap()
        XCTAssertTrue(app.staticTexts["ai-result-score"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["ai-result-score"].label, score)
    }

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
        #if !DEBUG
        throw XCTSkip("The fixture-server integration test runs in Debug.")
        #else
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
        #endif
    }

    @MainActor
    func testCachedAudioRefreshesWithoutLosingAnswers() async throws {
        #if !DEBUG
        throw XCTSkip("The fixture-server integration test runs in Debug.")
        #else
        do {
            let (_, response) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:8766/health")!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.cannotConnectToHost) }
        } catch {
            throw XCTSkip("Start backend/tests/fixture_server.py on port 8766 to run the cache-refresh test.")
        }
        let sessionID = UUID().uuidString.lowercased()
        let app = XCUIApplication()
        app.launchArguments = ["-test-ai-listening"]
        app.launchEnvironment = ["TCF_BACKEND_URL": "http://127.0.0.1:8766", "TCF_BACKEND_TOKEN": "ui-test-token", "TCF_LISTENING_SESSION_ID": sessionID]
        app.launch()
        XCTAssertTrue(app.buttons["start-ai-listening"].waitForExistence(timeout: 45))
        app.buttons["start-ai-listening"].tap()
        app.buttons["ai-answer-0"].tap()
        XCTAssertEqual(app.staticTexts["audio-duration-1"].label, "00:00")
        app.terminate()
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8766/test/update-audio/" + sessionID)!)
        request.httpMethod = "POST"
        request.setValue("Bearer ui-test-token", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        app.launch()
        XCTAssertTrue(app.buttons["ai-next"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["ai-next"].isEnabled)
        XCTAssertEqual(app.staticTexts["audio-duration-1"].label, "00:01")
        #endif
    }

    @MainActor
    func testOnlyGeneratedPracticeIsOffered() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["listen_ai"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["MES TESTS"].exists)
        XCTAssertFalse(app.buttons["Examen"].exists)
        XCTAssertFalse(app.buttons["Scores"].exists)
        XCTAssertFalse(app.buttons["read_a1_a2"].exists)
        XCTAssertFalse(app.buttons["listen_yt11"].exists)
        XCTAssertFalse(app.buttons["write_t1"].exists)
        XCTAssertFalse(app.buttons["speak_t1"].exists)
        XCTAssertFalse(app.staticTexts["SÉRIES DISPONIBLES HORS LIGNE"].exists)
    }
}
