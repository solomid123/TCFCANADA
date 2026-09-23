import SwiftUI

struct GeneratedExamView: View {
    @Binding var isSessionActive: Bool
    var onShowPractice: () -> Void
    @State private var isShowingSession = false

    var body: some View {
        VStack(spacing: 0) {
            if isShowingSession {
                AIListeningSessionView(onBack: {
                    isShowingSession = false
                    isSessionActive = false
                    onShowPractice()
                }, startNewSession: true)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Examen blanc")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Préparez votre prochaine épreuve avec la banque de tests.")
                            .font(.subheadline).foregroundStyle(TCFTheme.textSecondary)
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: "headphones.circle")
                                .font(.system(size: 48, weight: .light)).foregroundStyle(TCFTheme.emerald)
                            Text("Compréhension orale").font(.title2.bold())
                            Text("39 questions · Difficulté progressive")
                                .font(.subheadline.weight(.medium))
                            Text("Épreuve d'entraînement à votre rythme. Les corrections et les transcriptions sont disponibles après la dernière question.")
                                .font(.subheadline).foregroundStyle(TCFTheme.textSecondary)
                            Button { isShowingSession = true } label: {
                                Label("Préparer l'épreuve d'écoute", systemImage: "arrow.right")
                                    .frame(maxWidth: .infinity).padding(.vertical, 8).foregroundStyle(.white)
                            }
                            .whiteGlassButton(isPrimary: true)
                            .accessibilityIdentifier("prepare-generated-exam")
                        }
                        .whiteGlassCard(cornerRadius: 26, padding: 22)
                        Text("Les épreuves de lecture, d'écriture et de parole seront ajoutées lorsque leurs banques seront disponibles.")
                            .font(.caption).foregroundStyle(TCFTheme.textSecondary)
                    }
                    .foregroundStyle(TCFTheme.textPrimary)
                    .padding(22)
                }
            }
        }
        .onAppear { isSessionActive = isShowingSession }
        .onChange(of: isShowingSession) { _, active in isSessionActive = active }
    }
}
