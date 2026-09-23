import SwiftUI

struct TCFDashboardView: View {
    @Binding var selectedTab: Int

    @State private var targetNCLC: Int = 7
    @State private var studyStreakDays: Int = 5

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 22) {
                // Header Brand & Title
                headerView

                // Target NCLC 7 Immigration Status Card
                targetNCLCCard

                // 4 Section Tiles (Spacious & Clean)
                sectionsGrid

                // Connecteurs Logiques Preview
                connectorsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(TCFTheme.mapleRed)
                        .font(.system(size: 13))

                    Text("TCF CANADA")
                        .font(.centuryGothic(11, weight: .bold))
                        .foregroundColor(TCFTheme.textSecondary)
                        .tracking(1.5)
                }

                Text("Préparation")
                    .font(.centuryGothic(28, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)

                Text("Objectif Immigration Express Entry")
                    .font(.centuryGothic(13, weight: .regular))
                    .foregroundColor(TCFTheme.textMuted)
            }

            Spacer()

            // Streak Badge
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .foregroundColor(TCFTheme.amber)
                    .font(.system(size: 12))
                Text("\(studyStreakDays)j")
                    .font(.centuryGothic(14, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.8))
                    .background(Capsule().fill(.ultraThinMaterial))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Target Card
    private var targetNCLCCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CIBLE OFFICIELLE")
                        .font(.centuryGothic(10, weight: .bold))
                        .foregroundColor(TCFTheme.textMuted)
                        .tracking(1.0)
                    Text("Niveau NCLC 7 (B2)")
                        .font(.centuryGothic(17, weight: .bold))
                        .foregroundColor(TCFTheme.emerald)
                }

                Spacer()

                NCLCBadge(level: 7, isTarget: true)
            }

            Text("L'atteinte du NCLC 7 dans les 4 épreuves vous confère jusqu'à 50 points bonus CRS dans le bassin Entrée Express.")
                .font(.centuryGothic(13, weight: .regular))
                .foregroundColor(TCFTheme.textSecondary)
                .lineSpacing(4)

            HStack(spacing: 12) {
                targetPill(title: "C.É.", score: "≥ 453")
                targetPill(title: "C.O.", score: "≥ 458")
                targetPill(title: "E.É.", score: "≥ 10/20")
                targetPill(title: "E.O.", score: "≥ 10/20")
            }
        }
        .whiteGlassCard()
    }

    private func targetPill(title: String, score: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.centuryGothic(10, weight: .bold))
                .foregroundColor(TCFTheme.textMuted)
            Text(score)
                .font(.centuryGothic(12, weight: .bold))
                .foregroundColor(TCFTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
        )
    }

    // MARK: - Sections Grid
    private var sectionsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ÉPREUVES D'EXAMEN")
                .font(.centuryGothic(11, weight: .bold))
                .foregroundColor(TCFTheme.textMuted)
                .tracking(1.2)
                .padding(.leading, 4)

            VStack(spacing: 12) {
                sectionRow(
                    title: "Compréhension Écrite",
                    subtitle: "39 questions • 60 minutes",
                    badge: "Lecture",
                    icon: "book.fill",
                    color: TCFTheme.azureBlue,
                    action: { selectedTab = 1 }
                )

                sectionRow(
                    title: "Compréhension Orale",
                    subtitle: "39 questions • 35 minutes",
                    badge: "Écoute",
                    icon: "headphones",
                    color: TCFTheme.emerald,
                    action: { selectedTab = 2 }
                )

                sectionRow(
                    title: "Expression Écrite",
                    subtitle: "3 tâches • 60 minutes",
                    badge: "Rédaction",
                    icon: "pencil.line",
                    color: TCFTheme.amber,
                    action: { selectedTab = 3 }
                )

                sectionRow(
                    title: "Expression Orale",
                    subtitle: "3 tâches • 12 minutes",
                    badge: "Entretien",
                    icon: "mic.fill",
                    color: TCFTheme.mapleRed,
                    action: { selectedTab = 4 }
                )
            }
        }
    }

    private func sectionRow(title: String, subtitle: String, badge: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.centuryGothic(15, weight: .bold))
                        .foregroundColor(TCFTheme.textPrimary)
                    Text(subtitle)
                        .font(.centuryGothic(12, weight: .regular))
                        .foregroundColor(TCFTheme.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(TCFTheme.textMuted)
            }
        }
        .whiteGlassCard(cornerRadius: 18, padding: 14)
        .buttonStyle(.plain)
    }

    // MARK: - Connecteurs Card
    private var connectorsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CONNECTEURS LOGIQUES")
                    .font(.centuryGothic(11, weight: .bold))
                    .foregroundColor(TCFTheme.textMuted)
                    .tracking(1.0)
                Spacer()
                Text("Essentiels")
                    .font(.centuryGothic(11, weight: .bold))
                    .foregroundColor(TCFTheme.azureBlue)
            }

            VStack(spacing: 8) {
                connectorRow(fr: "En premier lieu", en: "First of all", cat: "Ordre")
                connectorRow(fr: "D'une part... d'autre part", en: "On the one hand... on the other", cat: "Nuance")
                connectorRow(fr: "Néanmoins / Cependant", en: "However / Nevertheless", cat: "Opposition")
                connectorRow(fr: "En conclusion / Ainsi", en: "In conclusion / Thus", cat: "Conclusion")
            }
        }
        .whiteGlassCard()
    }

    private func connectorRow(fr: String, en: String, cat: String) -> some View {
        HStack {
            Text(fr)
                .font(.centuryGothic(13, weight: .bold))
                .foregroundColor(TCFTheme.textPrimary)
            Spacer()
            Text(en)
                .font(.centuryGothic(11, weight: .regular))
                .foregroundColor(TCFTheme.textMuted)
        }
        .padding(.vertical, 4)
    }
}
