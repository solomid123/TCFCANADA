import SwiftUI

struct ContentView: View {
    @State private var selectedTab = ProcessInfo.processInfo.arguments.contains("-test-exam") ? 1 : 0
    @State private var isPracticeActive = false
    @State private var isExamActive = false
    @Namespace private var tabSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFocused: Bool { isPracticeActive || isExamActive }

    var body: some View {
        ZStack {
            TCFGlassBackground()
            VStack(spacing: 0) {
                if !isFocused { topBar }
                Group {
                    switch selectedTab {
                    case 1: FullExamSessionView(isSessionActive: $isExamActive)
                    case 2: NCLCCalculatorView()
                    default: PreparationView(isPracticeActive: $isPracticeActive)
                    }
                }
                .frame(maxWidth: 760, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isFocused {
                floatingTabBar
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isFocused)
        .preferredColorScheme(.light)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill").foregroundStyle(TCFTheme.emerald)
            Text("TCF CANADA").tracking(2).foregroundStyle(TCFTheme.textPrimary)
            Spacer()
            NCLCBadge(level: 7, isTarget: true)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: 760)
    }

    private var floatingTabBar: some View {
        HStack(spacing: 4) {
            tabItem(title: "Pratique", icon: "square.grid.2x2", index: 0)
            tabItem(title: "Examen", icon: "timer", index: 1)
            tabItem(title: "Scores", icon: "chart.bar.xaxis", index: 2)
        }
        .padding(7)
        .tcfGlass(cornerRadius: 36)
        .frame(maxWidth: 420)
    }

    private func tabItem(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 19, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selectedTab == index ? TCFTheme.azureBlue : TCFTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if selectedTab == index {
                    Capsule().fill(.white.opacity(0.6))
                        .matchedGeometryEffect(id: "selected-tab", in: tabSelection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }
}

#Preview { ContentView() }
