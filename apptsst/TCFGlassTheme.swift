import SwiftUI

enum TCFTheme {
    static let canvasBg = Color(red: 0.94, green: 0.96, blue: 0.97)
    static let canvasGradientTop = Color(red: 0.91, green: 0.95, blue: 0.98)
    static let canvasGradientBottom = Color(red: 0.95, green: 0.94, blue: 0.97)
    static let glassSurface = Color.white.opacity(0.22)
    static let glassSurfaceHigh = Color.white.opacity(0.4)
    static let glassBorder = Color.white.opacity(0.8)
    static let glassBorderSubtle = Color.black.opacity(0.05)
    static let textPrimary = Color(red: 0.10, green: 0.17, blue: 0.22)
    static let textSecondary = Color(red: 0.32, green: 0.40, blue: 0.46)
    static let textMuted = Color(red: 0.40, green: 0.47, blue: 0.53)
    static let mapleRed = Color(red: 0.75, green: 0.23, blue: 0.34)
    static let azureBlue = Color(red: 0.16, green: 0.37, blue: 0.60)
    static let emerald = Color(red: 0.12, green: 0.46, blue: 0.39)
    static let amber = Color(red: 0.62, green: 0.40, blue: 0.14)
}

// Color behind a translucent surface gives the glass its depth.
struct TCFGlassBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [TCFTheme.canvasGradientTop, TCFTheme.canvasBg, TCFTheme.canvasGradientBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                Ellipse()
                    .fill(Color(red: 0.52, green: 0.77, blue: 0.87).opacity(0.5))
                    .frame(width: geometry.size.width * 0.95, height: geometry.size.height * 0.5)
                    .blur(radius: 65)
                    .offset(x: geometry.size.width * 0.38, y: -geometry.size.height * 0.27)
                Ellipse()
                    .fill(Color(red: 0.64, green: 0.83, blue: 0.76).opacity(0.45))
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.38)
                    .blur(radius: 70)
                    .offset(x: -geometry.size.width * 0.4, y: geometry.size.height * 0.1)
                Ellipse()
                    .fill(Color(red: 0.76, green: 0.69, blue: 0.86).opacity(0.35))
                    .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.3)
                    .blur(radius: 65)
                    .offset(x: geometry.size.width * 0.35, y: geometry.size.height * 0.4)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension Font {
    static func centuryGothic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func centuryGothicTitle(_ size: CGFloat = 24) -> Font { centuryGothic(size, weight: .bold) }
    static func centuryGothicBody(_ size: CGFloat = 16) -> Font { centuryGothic(size) }
    static func centuryGothicMedium(_ size: CGFloat = 16) -> Font { centuryGothic(size, weight: .medium) }
}

struct TCFGlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 24
    var interactive = false
    var tint: Color? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content.background(tint ?? Color.white, in: shape)
                .overlay(shape.strokeBorder(TCFTheme.glassBorderSubtle))
        } else if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background((tint ?? Color.white).opacity(tint == nil ? 0.12 : 0.85), in: shape)
                .overlay(shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.18), .white.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .shadow(color: TCFTheme.textPrimary.opacity(0.07), radius: 18, x: 0, y: 8)
        }
    }
}

struct WhiteGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content.padding(padding).modifier(TCFGlassSurface(cornerRadius: cornerRadius))
    }
}

struct WhiteGlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 18
    var isPrimary = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: 44)
            .modifier(TCFGlassSurface(cornerRadius: cornerRadius, interactive: true, tint: isPrimary ? TCFTheme.azureBlue : nil))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func tcfGlass(cornerRadius: CGFloat = 24, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(TCFGlassSurface(cornerRadius: cornerRadius, interactive: interactive, tint: tint))
    }
    func whiteGlassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 18) -> some View {
        modifier(WhiteGlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
    func liquidGlassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 18) -> some View {
        whiteGlassCard(cornerRadius: cornerRadius, padding: padding)
    }
    func whiteGlassButton(cornerRadius: CGFloat = 18, isPrimary: Bool = false) -> some View {
        buttonStyle(WhiteGlassButtonStyle(cornerRadius: cornerRadius, isPrimary: isPrimary))
    }
    func liquidGlassButton(cornerRadius: CGFloat = 18, isPrimary: Bool = false) -> some View {
        whiteGlassButton(cornerRadius: cornerRadius, isPrimary: isPrimary)
    }
}

// Levels are quiet, readable metadata rather than competing blue action chips.
struct TCFLevelLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(TCFTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(TCFTheme.textPrimary.opacity(0.045), in: Capsule())
            .accessibilityLabel("Niveau \(text)")
    }
}

struct NCLCBadge: View {
    var level: Int
    var isTarget = false
    var body: some View {
        Label("NCLC \(level)", systemImage: isTarget ? "scope" : "chart.bar.fill")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(level >= 7 ? TCFTheme.emerald : TCFTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.35), in: Capsule())
    }
}

struct TCFPracticeResultView: View {
    let correct: Int
    let total: Int
    let onRetry: () -> Void
    let onDone: () -> Void

    var body: some View {
        ZStack {
            TCFGlassBackground()
            VStack(spacing: 22) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 52, weight: .light)).foregroundStyle(TCFTheme.emerald)
                Text("Série terminée")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("\(correct) / \(total)")
                    .font(.system(size: 52, weight: .medium, design: .rounded))
                Text("bonnes réponses").foregroundStyle(TCFTheme.textSecondary)
                Button(action: onRetry) {
                    Text("Recommencer").frame(maxWidth: .infinity).padding(.vertical, 8).foregroundStyle(.white)
                }
                .whiteGlassButton(isPrimary: true)
                Button(action: onDone) {
                    Text("Retour aux pratiques").frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .whiteGlassButton()
            }
            .foregroundStyle(TCFTheme.textPrimary).padding(30)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
