import SwiftUI

struct ContentView: View {
    @State private var isPracticeActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            TCFGlassBackground()
            VStack(spacing: 0) {
                if !isPracticeActive {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill").foregroundStyle(TCFTheme.emerald)
                        Text("TCF CANADA").tracking(2)
                        Spacer()
                        NCLCBadge(level: 7, isTarget: true)
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(TCFTheme.textPrimary)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                }
                PreparationView(isPracticeActive: $isPracticeActive)
            }
            .frame(maxWidth: 760, maxHeight: .infinity)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isPracticeActive)
        .preferredColorScheme(.light)
    }
}

#Preview { ContentView() }
