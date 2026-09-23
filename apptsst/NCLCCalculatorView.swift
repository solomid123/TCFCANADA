import SwiftUI

struct NCLCCalculatorView: View {
    @State private var readingScore = 460.0
    @State private var listeningScore = 470.0
    @State private var writingScore = 11.0
    @State private var speakingScore = 11.0
    @State private var hasEnglishCLB5 = true

    private var levels: [Int] {
        [NCLCScoreEngine.readingToNCLC(Int(readingScore)), NCLCScoreEngine.listeningToNCLC(Int(listeningScore)),
         NCLCScoreEngine.writingToNCLC(Int(writingScore)), NCLCScoreEngine.speakingToNCLC(Int(speakingScore))]
    }
    private var bonus: Int {
        NCLCScoreEngine.calculateFrenchBonusCRS(reading: Int(readingScore), listening: Int(listeningScore), writing: Int(writingScore), speaking: Int(speakingScore), hasEnglishCLB5Plus: hasEnglishCLB5)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Score NCLC & Points CRS")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(levels.allSatisfy { $0 >= 7 } ? "OBJECTIF NCLC 7 ATTEINT" : "OBJECTIF NCLC 7")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(TCFTheme.emerald)
                            Text("Bonus CRS pour le français").font(.subheadline)
                        }
                        Spacer()
                        Text("+\(bonus)").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(TCFTheme.emerald)
                    }
                    HStack {
                        ForEach(Array(zip(["C.É.", "C.O.", "E.É.", "E.O."], levels)), id: \.0) { title, level in
                            VStack(spacing: 5) {
                                Text(title).font(.caption).foregroundStyle(TCFTheme.textSecondary)
                                Text("NCLC \(level)").font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .whiteGlassCard()
                VStack(alignment: .leading, spacing: 20) {
                    Text("AJUSTER VOS SCORES").font(.system(size: 11, weight: .bold)).tracking(1)
                    scoreSlider("Compréhension écrite", value: $readingScore, range: 100...699, level: levels[0])
                    scoreSlider("Compréhension orale", value: $listeningScore, range: 100...699, level: levels[1])
                    scoreSlider("Expression écrite", value: $writingScore, range: 0...20, level: levels[2])
                    scoreSlider("Expression orale", value: $speakingScore, range: 0...20, level: levels[3])
                }
                .whiteGlassCard()
                Toggle(isOn: $hasEnglishCLB5) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Anglais CLB 5+").font(.subheadline.weight(.semibold))
                        Text("IELTS / CELPIP · 50 points au lieu de 25").font(.caption).foregroundStyle(TCFTheme.textSecondary)
                    }
                }
                .tint(TCFTheme.emerald).whiteGlassCard()
                Text("Saisissez vos scores TCF pour consulter leur équivalence NCLC. Le résultat d'un test d'entraînement sur 39 questions ne se convertit pas directement en score officiel.")
                    .font(.caption).foregroundStyle(TCFTheme.textSecondary)
            }
            .foregroundStyle(TCFTheme.textPrimary).padding(22)
        }
    }

    private func scoreSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, level: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(Int(value.wrappedValue))/\(Int(range.upperBound))").font(.caption.monospacedDigit())
                NCLCBadge(level: level)
            }
            Slider(value: value, in: range, step: 1).tint(TCFTheme.emerald).accessibilityLabel(title)
        }
    }
}
