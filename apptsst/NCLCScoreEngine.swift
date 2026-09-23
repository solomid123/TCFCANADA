import Foundation

enum NCLCScoreEngine {
    static func readingToNCLC(_ score: Int) -> Int {
        switch score {
        case ..<342: return 3
        case 342...374: return 4
        case 375...405: return 5
        case 406...452: return 6
        case 453...498: return 7
        case 499...523: return 8
        case 524...548: return 9
        default: return 10
        }
    }

    static func listeningToNCLC(_ score: Int) -> Int {
        switch score {
        case ..<331: return 3
        case 331...368: return 4
        case 369...397: return 5
        case 398...457: return 6
        case 458...502: return 7
        case 503...522: return 8
        case 523...548: return 9
        default: return 10
        }
    }

    static func writingToNCLC(_ score: Int) -> Int {
        switch score {
        case ..<4: return 3
        case 4...5: return 4
        case 6: return 5
        case 7...9: return 6
        case 10...11: return 7
        case 12...13: return 8
        case 14...15: return 9
        default: return 10
        }
    }

    static func speakingToNCLC(_ score: Int) -> Int { writingToNCLC(score) }

    static func calculateFrenchBonusCRS(reading: Int, listening: Int, writing: Int, speaking: Int, hasEnglishCLB5Plus: Bool) -> Int {
        let allNCLC7Plus = readingToNCLC(reading) >= 7 && listeningToNCLC(listening) >= 7 && writingToNCLC(writing) >= 7 && speakingToNCLC(speaking) >= 7
        return allNCLC7Plus ? (hasEnglishCLB5Plus ? 50 : 25) : 0
    }
}
