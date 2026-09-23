import SwiftUI

struct TCFIdeasBankView: View {
    var onBack: (() -> Void)? = nil

    @State private var selectedCategory: String = "Tous"
    @State private var searchText: String = ""
    @State private var expandedTopicId: String? = "teletravail" // Default first topic open
    @State private var copiedTopicId: String? = nil

    private let categories = [
        "Tous",
        "Travail",
        "Environnement",
        "Transports",
        "Société",
        "Technologie",
        "Éducation",
        "Culture",
        "Voyage"
    ]

    private var filteredTopics: [TCFIdeaTopic] {
        TCFMockData.ideasBank.filter { topic in
            let matchesCategory = selectedCategory == "Tous" || topic.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                topic.title.localizedCaseInsensitiveContains(searchText) ||
                topic.examContext.localizedCaseInsensitiveContains(searchText) ||
                topic.avantages.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                topic.inconvenients.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // Search & Category Filters
                    searchAndFilterSection

                    // Method Advice Card for TCF Canada Tâches 2 & 3
                    methodStrategyCard

                    // Topic Cards List
                    VStack(spacing: 14) {
                        ForEach(filteredTopics) { topic in
                            topicCard(topic)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            if let onBack = onBack {
                Button(action: {
                    onBack()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("Pratiques")
                            .font(.centuryGothic(12.5, weight: .bold))
                    }
                    .foregroundColor(TCFTheme.azureBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(TCFTheme.azureBlue.opacity(0.10))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("GUIDE OFFICIEL TCF 2026")
                    .font(.centuryGothic(10, weight: .bold))
                    .foregroundColor(TCFTheme.textMuted)
                    .tracking(1.0)

                Text("Banque d'Idées & Arguments")
                    .font(.centuryGothic(15, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(filteredTopics.count) thèmes")
                .font(.centuryGothic(11, weight: .bold))
                .foregroundColor(TCFTheme.azureBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(TCFTheme.azureBlue.opacity(0.12)))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.35))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.98), location: 0.0),
                            .init(color: Color.white.opacity(0.35), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Search & Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 10) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(TCFTheme.textMuted)

                TextField("Rechercher un thème (ex. télétravail, vélo, bio...)", text: $searchText)
                    .font(.centuryGothic(13.5))
                    .foregroundColor(TCFTheme.textPrimary)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(TCFTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.40))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(categories, id: \.self) { cat in
                        let isSelected = selectedCategory == cat
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedCategory = cat
                            }
                        }) {
                            Text(cat)
                                .font(.centuryGothic(11.5, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : TCFTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            isSelected ?
                                            LinearGradient(colors: [TCFTheme.azureBlue, Color(red: 0.05, green: 0.38, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                            LinearGradient(colors: [Color.white.opacity(0.70), Color.white.opacity(0.40)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.clear : Color.black.opacity(0.06), lineWidth: 0.8)
                                )
                                .shadow(color: isSelected ? TCFTheme.azureBlue.opacity(0.25) : Color.clear, radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Method Strategy Card (TCF Tâche 2 & 3 Success Formula)
    private var methodStrategyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(TCFTheme.azureBlue)

                Text("Méthode Officielle Tâches 2 & 3 (NCLC 7+)")
                    .font(.centuryGothic(12.5, weight: .bold))
                    .foregroundColor(TCFTheme.textPrimary)

                Spacer()

                Text("Guide 2026")
                    .font(.centuryGothic(10, weight: .bold))
                    .foregroundColor(TCFTheme.emerald)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(TCFTheme.emerald.opacity(0.12)))
            }

            Text("Pour obtenir NCLC 7 à 10, structurez systématiquement votre propos : un argument n'a de valeur que s'il est étayé par un exemple concret (ex. : chiffres, faits d'actualité ou observation personnelle).")
                .font(.centuryGothic(12, weight: .regular))
                .foregroundColor(TCFTheme.textSecondary)
                .lineSpacing(3)

            HStack(spacing: 8) {
                stepBadge(num: "1", text: "Thèse & Contexte")
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(TCFTheme.textMuted)
                stepBadge(num: "2", text: "Pour (2 arguments)")
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(TCFTheme.textMuted)
                stepBadge(num: "3", text: "Contre & Nuance")
            }
        }
        .whiteGlassCard(cornerRadius: 16, padding: 14)
    }

    private func stepBadge(num: String, text: String) -> some View {
        HStack(spacing: 4) {
            Text(num)
                .font(.centuryGothic(9.5, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(TCFTheme.azureBlue))

            Text(text)
                .font(.centuryGothic(10.5, weight: .medium))
                .foregroundColor(TCFTheme.textPrimary)
        }
    }

    // MARK: - Topic Card (Liquid Glass Expandable)
    private func topicCard(_ topic: TCFIdeaTopic) -> some View {
        let isExpanded = expandedTopicId == topic.id

        return VStack(alignment: .leading, spacing: 12) {
            // Header Button (Toggles expansion)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedTopicId = nil
                    } else {
                        expandedTopicId = topic.id
                    }
                }
            }) {
                HStack(spacing: 12) {
                    // Static Vector Icon
                    ZStack {
                        Circle()
                            .fill(TCFTheme.azureBlue.opacity(0.09))
                            .frame(width: 42, height: 42)

                        Image(systemName: topic.iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(TCFTheme.azureBlue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(topic.category.uppercased())
                                .font(.centuryGothic(9.5, weight: .bold))
                                .foregroundColor(TCFTheme.azureBlue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(TCFTheme.azureBlue.opacity(0.12)))

                            Text(topic.taskScope)
                                .font(.centuryGothic(9.5, weight: .bold))
                                .foregroundColor(TCFTheme.textMuted)
                        }

                        Text(topic.title)
                            .font(.centuryGothic(15, weight: .bold))
                            .foregroundColor(TCFTheme.textPrimary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(TCFTheme.textMuted)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.black.opacity(0.03)))
                }
            }
            .buttonStyle(.plain)

            // Expanded Body
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()
                        .background(Color.black.opacity(0.06))

                    // Exam Prompt
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SUJET TYPE D'EXAMEN")
                            .font(.centuryGothic(9.5, weight: .bold))
                            .foregroundColor(TCFTheme.textMuted)
                            .tracking(0.8)

                        Text(topic.sujetTypeExam)
                            .font(.centuryGothic(13, weight: .medium))
                            .foregroundColor(TCFTheme.textPrimary)
                            .italic()
                            .lineSpacing(3)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.10), lineWidth: 0.8)
                                    )
                            )
                    }

                    // Arguments POUR (Avantages)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(TCFTheme.emerald)

                            Text("Arguments POUR (Avantages & Exemples)")
                                .font(.centuryGothic(12.5, weight: .bold))
                                .foregroundColor(TCFTheme.emerald)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(topic.avantages, id: \.self) { av in
                                HStack(alignment: .top, spacing: 7) {
                                    Text("•")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(TCFTheme.emerald)

                                    Text(av)
                                        .font(.centuryGothic(12.5, weight: .regular))
                                        .foregroundColor(TCFTheme.textPrimary)
                                        .lineSpacing(2.5)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(TCFTheme.emerald.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(TCFTheme.emerald.opacity(0.18), lineWidth: 0.8)
                                )
                        )
                    }

                    // Arguments CONTRE (Inconvénients)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(TCFTheme.mapleRed)

                            Text("Arguments CONTRE (Inconvénients & Limites)")
                                .font(.centuryGothic(12.5, weight: .bold))
                                .foregroundColor(TCFTheme.mapleRed)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(topic.inconvenients, id: \.self) { inc in
                                HStack(alignment: .top, spacing: 7) {
                                    Text("•")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(TCFTheme.mapleRed)

                                    Text(inc)
                                        .font(.centuryGothic(12.5, weight: .regular))
                                        .foregroundColor(TCFTheme.textPrimary)
                                        .lineSpacing(2.5)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(TCFTheme.mapleRed.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(TCFTheme.mapleRed.opacity(0.18), lineWidth: 0.8)
                                )
                        )
                    }

                    // Recommended Connectors
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CONNECTEURS CLÉS CONSEILLÉS")
                            .font(.centuryGothic(9.5, weight: .bold))
                            .foregroundColor(TCFTheme.textMuted)
                            .tracking(0.8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(topic.connecteursRecommandes, id: \.self) { conn in
                                    Text(conn)
                                        .font(.centuryGothic(11, weight: .medium))
                                        .foregroundColor(TCFTheme.textPrimary)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.white.opacity(0.8)))
                                        .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.8))
                                }
                            }
                        }
                    }

                    // Copy Action Button
                    Button(action: {
                        copyTopicToClipboard(topic)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: copiedTopicId == topic.id ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12, weight: .bold))
                            Text(copiedTopicId == topic.id ? "Arguments Copiés !" : "Copier les arguments pour mon essai")
                                .font(.centuryGothic(12, weight: .bold))
                        }
                        .foregroundColor(copiedTopicId == topic.id ? TCFTheme.emerald : TCFTheme.azureBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(copiedTopicId == topic.id ? TCFTheme.emerald.opacity(0.10) : TCFTheme.azureBlue.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .whiteGlassCard(cornerRadius: 18, padding: 16)
    }

    private func copyTopicToClipboard(_ topic: TCFIdeaTopic) {
        #if canImport(UIKit)
        var text = "=== THÈME : \(topic.title) ===\n"
        text += "Sujet : \(topic.sujetTypeExam)\n\n"
        text += "POUR :\n"
        for av in topic.avantages { text += "• \(av)\n" }
        text += "\nCONTRE :\n"
        for inc in topic.inconvenients { text += "• \(inc)\n" }
        text += "\nConnecteurs : \(topic.connecteursRecommandes.joined(separator: ", "))\n"
        UIPasteboard.general.string = text
        #endif

        withAnimation {
            copiedTopicId = topic.id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                if copiedTopicId == topic.id {
                    copiedTopicId = nil
                }
            }
        }
    }
}
