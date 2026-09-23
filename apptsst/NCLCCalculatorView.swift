import SwiftUI

struct NCLCCalculatorView: View {
    @State private var readingScore: Double = 460
    @State private var listeningScore: Double = 470
    @State private var writingScore: Double = 11
    @State private var speakingScore: Double = 11
    @State private var hasEnglishCLB5: Bool = true

    var readingNCLC: Int { NCLCScoreEngine.readingToNCLC(Int(readingScore)) }
    var listeningNCLC: Int { NCLCScoreEngine.listeningToNCLC(Int(listeningScore)) }
    var writingNCLC: Int { NCLCScoreEngine.writingToNCLC(Int(writingScore)) }
    var speakingNCLC: Int { NCLCScoreEngine.speakingToNCLC(Int(speakingScore)) }

    var allNCLC7Plus: Bool {
        readingNCLC >= 7 && listeningNCLC >= 7 && writingNCLC >= 7 && speakingNCLC >= 7
    }

    var bonusCRS: Int {
        NCLCScoreEngine.calculateFrenchBonusCRS(
            reading: Int(readingScore),
            listening: Int(listeningScore),
            writing: Int(writingScore),
            speaking: Int(speakingScore),
            hasEnglishCLB5Plus: hasEnglishCLB5
        )
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                // Header
                headerCard

                // CRS Result Card
                crsResultCard

                // Sliders Card
                scoreSlidersCard

                // English Toggle
                englishToggleCard

                // Reference Table
                referenceCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Header
    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("CALCULATEUR")
                    .font(.centuryGothic(12, weight: .bold))
                    .foregroundColor(TCFTheme.textMuted)
                    .tracking(1.2)
                Text("Score NCLC & Points CRS")
                    .font(.centuryGothic(18, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)
            }

            Spacer()

            NCLCBadge(level: allNCLC7Plus ? 7 : min(readingNCLC, listeningNCLC, writingNCLC, speakingNCLC))
        }
        .whiteGlassCard(cornerRadius: 18, padding: 16)
    }

    // MARK: - CRS Result Card
    private var crsResultCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(allNCLC7Plus ? "OBJECTIF NCLC 7 ATTEINT" : "EN COURS D'ACQUISITION")
                        .font(.centuryGothic(12, weight: .bold))
                        .foregroundColor(allNCLC7Plus ? TCFTheme.emerald : TCFTheme.amber)

                    Text(allNCLC7Plus ? "Points bonus débloqués pour le français." : "Le NCLC 7 est requis dans les 4 compétences.")
                        .font(.centuryGothic(12, weight: .regular))
                        .foregroundColor(TCFTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text("+\(bonusCRS)")
                        .font(.centuryGothic(26, weight: .bold))
                        .foregroundColor(allNCLC7Plus ? TCFTheme.emerald : TCFTheme.textMuted)
                    Text("POINTS CRS")
                        .font(.centuryGothic(9, weight: .bold))
                        .foregroundColor(TCFTheme.textMuted)
                }
            }

            HStack(spacing: 8) {
                pill(title: "C.É.", nclc: readingNCLC)
                pill(title: "C.O.", nclc: listeningNCLC)
                pill(title: "E.É.", nclc: writingNCLC)
                pill(title: "E.O.", nclc: speakingNCLC)
            }
        }
        .whiteGlassCard()
    }

    private func pill(title: String, nclc: Int) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.centuryGothic(10, weight: .bold))
                .foregroundColor(TCFTheme.textMuted)
            Text("NCLC \(nclc)")
                .font(.centuryGothic(12, weight: .bold))
                .foregroundColor(nclc >= 7 ? TCFTheme.emerald : TCFTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.8)))
    }

    // MARK: - Sliders Card
    private var scoreSlidersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AJUSTER VOS SCORES")
                .font(.centuryGothic(11, weight: .bold))
                .foregroundColor(TCFTheme.textMuted)
                .tracking(1.0)

            sliderRow(title: "Compréhension Écrite", value: $readingScore, range: 100...699, display: "\(Int(readingScore))/699", nclc: readingNCLC)
            sliderRow(title: "Compréhension Orale", value: $listeningScore, range: 100...699, display: "\(Int(listeningScore))/699", nclc: listeningNCLC)
            sliderRow(title: "Expression Écrite", value: $writingScore, range: 0...20, display: "\(Int(writingScore))/20", nclc: writingNCLC)
            sliderRow(title: "Expression Orale", value: $speakingScore, range: 0...20, display: "\(Int(speakingScore))/20", nclc: speakingNCLC)
        }
        .whiteGlassCard()
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, display: String, nclc: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.centuryGothic(13, weight: .semibold))
                    .foregroundColor(TCFTheme.textPrimary)

                Spacer()

                Text(display)
                    .font(.centuryGothic(12, weight: .bold))
                    .foregroundColor(TCFTheme.textSecondary)

                Text("NCLC \(nclc)")
                    .font(.centuryGothic(11, weight: .bold))
                    .foregroundColor(nclc >= 7 ? TCFTheme.emerald : TCFTheme.azureBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill((nclc >= 7 ? TCFTheme.emerald : TCFTheme.azureBlue).opacity(0.12)))
            }

            Slider(value: value, in: range, step: 1)
                .tint(nclc >= 7 ? TCFTheme.emerald : TCFTheme.textPrimary)
        }
    }

    // MARK: - English Toggle
    private var englishToggleCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Anglais CLB 5+ (IELTS / CELPIP)")
                    .font(.centuryGothic(13, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)
                Text("Débloque 50 points au lieu de 25")
                    .font(.centuryGothic(11, weight: .regular))
                    .foregroundColor(TCFTheme.textMuted)
            }

            Spacer()

            Toggle("", isOn: $hasEnglishCLB5)
                .labelsHidden()
                .tint(TCFTheme.textPrimary)
        }
        .whiteGlassCard()
    }

    // MARK: - Reference Card
    private var referenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BARÈME OFFICIEL NCLC")
                .font(.centuryGothic(11, weight: .bold))
                .foregroundColor(TCFTheme.textMuted)
                .tracking(1.0)

            VStack(spacing: 6) {
                refRow(nclc: "NCLC 4", cefr: "A2", ecrit: "342-374", exp: "4-5")
                refRow(nclc: "NCLC 5", cefr: "B1", ecrit: "375-405", exp: "6")
                refRow(nclc: "NCLC 6", cefr: "B1+", ecrit: "406-452", exp: "7-9")
                refRow(nclc: "NCLC 7", cefr: "B2 (Cible)", ecrit: "453-498", exp: "10-11", isHighlight: true)
                refRow(nclc: "NCLC 8", cefr: "B2+", ecrit: "499-523", exp: "12-13")
                refRow(nclc: "NCLC 9", cefr: "C1", ecrit: "524-548", exp: "14-15")
            }
        }
        .whiteGlassCard()
    }

    private func refRow(nclc: String, cefr: String, ecrit: String, exp: String, isHighlight: Bool = false) -> some View {
        HStack {
            Text(nclc)
                .font(.centuryGothic(11, weight: .bold))
                .foregroundColor(isHighlight ? TCFTheme.emerald : TCFTheme.textPrimary)
                .frame(width: 60, alignment: .leading)

            Text(cefr)
                .font(.centuryGothic(10, weight: .medium))
                .foregroundColor(isHighlight ? TCFTheme.emerald : TCFTheme.textMuted)
                .frame(width: 70, alignment: .leading)

            Spacer()

            Text("Écrit: \(ecrit)")
                .font(.centuryGothic(10, weight: .regular))
                .foregroundColor(TCFTheme.textSecondary)

            Text("•")
                .foregroundColor(Color.black.opacity(0.15))

            Text("Exp: \(exp)/20")
                .font(.centuryGothic(10, weight: .regular))
                .foregroundColor(TCFTheme.textSecondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isHighlight ? TCFTheme.emerald.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}
