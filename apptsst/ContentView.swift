import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isPracticeActive = false
    @State private var isExamActive = false
    @Namespace private var tabSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFocused: Bool { isPracticeActive || isExamActive }

    var body: some View {
        ZStack {
            TCFGlassBackground()
            VStack(spacing: 0) {
                if !isFocused {
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
                Group {
                    switch selectedTab {
                    case 1: GeneratedExamView(isSessionActive: $isExamActive, onShowPractice: { selectedTab = 0 })
                    case 2: NCLCCalculatorView()
                    default: PreparationView(isPracticeActive: $isPracticeActive)
                    }
                }
            }
            .frame(maxWidth: 760, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isFocused {
                HStack(spacing: 4) {
                    tabItem("Pratique", icon: "square.grid.2x2", index: 0)
                    tabItem("Examen", icon: "timer", index: 1)
                    tabItem("Scores", icon: "chart.bar.xaxis", index: 2)
                }
                .padding(7)
                .tcfGlass(cornerRadius: 36)
                .frame(maxWidth: 420)
                .padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 8)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isFocused)
        .preferredColorScheme(.light)
    }

    private func tabItem(_ title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) { selectedTab = index }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 19, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selectedTab == index ? TCFTheme.azureBlue : TCFTheme.textSecondary)
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background {
                if selectedTab == index {
                    Capsule().fill(.white.opacity(0.6)).matchedGeometryEffect(id: "selected-tab", in: tabSelection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }
}

#Preview { ContentView() }
