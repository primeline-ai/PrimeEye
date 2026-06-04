import SwiftUI
import PrimeEyeKit

/// The notch UI: three states that morph with a spring. Black fill with square top
/// corners (so it merges with the physical notch) and rounded bottom corners.
struct NotchRootView: View {
    @ObservedObject var state: AppState
    @State private var pulse = false   // drives the breathing posture-nudge glow

    private var size: CGSize {
        switch state.display {
        case .collapsed:
            return CGSize(width: state.notchWidth, height: state.notchHeight + NotchLayout.collapsedHeightExtra)
        case .peek:
            return CGSize(width: NotchLayout.peekWidth, height: state.notchHeight + NotchLayout.peekHeight)
        case .expanded:
            return CGSize(width: NotchLayout.expandedWidth, height: state.notchHeight + NotchLayout.expandedHeight)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: NotchLayout.cornerRadius,
                bottomTrailingRadius: NotchLayout.cornerRadius,
                topTrailingRadius: 0
            )
            .fill(Color.black)
            .frame(width: size.width, height: size.height)
            .overlay(
                content
                    .padding(contentPadding)
                    .id(state.display)            // identity-replace per state...
                    .transition(.opacity)         // ...so content cross-fades in sync with the frame spring (RC P1 #3)
            )
            .overlay(glowBorder)                  // pulsing border (Phase 3)
            .overlay(notchTint)                   // pulsing color wash over the notch itself

            if state.warningStage != .none {
                nudgeBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: state.display)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: state.warningStage)
        .onAppear { pulse = true }     // start the continuous breathing animation
    }

    private var nudgeColor: Color { state.warningStage == .message ? .red : .orange }

    // MARK: posture nudge visuals (Phase 3)

    /// Pulsing glow hugging the notch shape. The breathing opacity + outward halo is the
    /// key to catching peripheral vision when the notch is collapsed (motion > a static
    /// border). Amber at the glow stage, red at the message stage. Invisible when posture ok.
    private var glowBorder: some View {
        let active = state.warningStage != .none
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: NotchLayout.cornerRadius,
            bottomTrailingRadius: NotchLayout.cornerRadius,
            topTrailingRadius: 0
        )
        .strokeBorder(nudgeColor, lineWidth: 3)
        .opacity(active ? (pulse ? 1.0 : 0.4) : 0)
        .shadow(color: nudgeColor.opacity(active ? (pulse ? 0.95 : 0.3) : 0),
                radius: active ? (pulse ? 17 : 6) : 0)
        .animation(active ? .easeInOut(duration: 0.65).repeatForever(autoreverses: true) : .default,
                   value: pulse)
    }

    /// The posture nudge banner: a solid, wide, pulsing pill below the notch, shown the moment
    /// posture goes bad - independent of whether the notch is collapsed. Amber = gentle (glow),
    /// red + bigger + faster = escalated (message). Solid fill + scale pulse + halo so it is
    /// impossible to miss peripherally (Robin HW feedback: border-only was too weak).
    private var nudgeBanner: some View {
        let urgent = state.warningStage == .message
        return HStack(spacing: 8) {
            Image(systemName: "arrow.up.circle.fill")
            Text("Sit up straight")
        }
        .font(.system(size: urgent ? 14 : 13, weight: .heavy))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .frame(minWidth: NotchLayout.peekWidth)
        .background(Capsule().fill(nudgeColor))
        .shadow(color: nudgeColor.opacity(0.9), radius: pulse ? 22 : 9)
        .scaleEffect(pulse ? (urgent ? 1.09 : 1.06) : 1.0)
        .opacity(pulse ? 1.0 : 0.8)
        .padding(.top, 8)
        .animation(.easeInOut(duration: urgent ? 0.4 : 0.55).repeatForever(autoreverses: true), value: pulse)
    }

    /// A pulsing color wash filling the notch shape itself during a nudge, so the notch (not
    /// just a border) becomes part of the alarm.
    private var notchTint: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: NotchLayout.cornerRadius,
            bottomTrailingRadius: NotchLayout.cornerRadius,
            topTrailingRadius: 0
        )
        .fill(nudgeColor)
        .opacity(state.warningStage != .none ? (pulse ? 0.5 : 0.2) : 0)
        .animation(state.warningStage != .none ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true) : .default, value: pulse)
    }

    private var contentPadding: EdgeInsets {
        switch state.display {
        case .collapsed: return EdgeInsets(top: 0, leading: 12, bottom: 3, trailing: 12)
        // top inset clears the physical notch dead-zone so content is never occluded
        case .peek: return EdgeInsets(top: state.notchHeight + 2, leading: 14, bottom: 6, trailing: 14)
        case .expanded: return EdgeInsets(top: state.notchHeight + 8, leading: 16, bottom: 12, trailing: 16)
        }
    }

    @ViewBuilder private var content: some View {
        switch state.display {
        case .collapsed: collapsed
        case .peek: peek
        case .expanded: expanded
        }
    }

    private var postureColor: Color {
        guard state.postureActive else { return .gray } // not monitored yet (Phase 3)
        if !state.userPresent { return .gray }          // away from the Mac -> paused, neutral
        return state.postureOK ? .green : .red
    }

    /// Honest posture labels: "posture off" when not monitoring, "away" when no one is at the
    /// Mac (paused, no nudge, no score hit), "measuring" until the first real frame, then the %.
    private var postureHeadline: String {
        guard state.postureActive else { return "posture off" }
        if !state.userPresent { return "away" }
        return state.postureMeasured ? "\(state.posturePercentToday)% good" : "measuring"
    }

    private var postureFooter: String {
        guard state.postureActive else { return "Posture  monitoring off - camera not running" }
        if !state.userPresent { return "Posture  paused - no one at the Mac (not counted)" }
        return state.postureMeasured
            ? "Posture today  \(state.posturePercentToday)% upright  ·  \(state.nudgesToday) nudges"
            : "Posture  calibrating / measuring..."
    }

    // MARK: states

    private var collapsed: some View {
        HStack {
            Text("\u{26A1}\(state.intents)").font(.system(size: 10, weight: .semibold))
            Spacer()
            Circle().fill(postureColor).frame(width: 7, height: 7)
        }
        .foregroundStyle(.white)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var peek: some View {
        HStack(spacing: 12) {
            Label("\(state.intents)", systemImage: "bolt.fill")
            Text(String(format: "%.2f", state.fitness))
            Circle().fill(postureColor).frame(width: 8, height: 8)
            Text(state.usageLabel)
            Text(shortPriority).lineLimit(1).truncationMode(.tail)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("STATUS").font(.system(size: 11, weight: .bold)).tracking(1)
                if !state.dataLive {
                    Text("demo data").font(.system(size: 9))
                        .foregroundStyle(.orange.opacity(0.85))
                } else if state.dataStale {
                    Text("stale").font(.system(size: 9))   // caches refresh on CC events, not continuously
                        .foregroundStyle(.gray)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(postureColor).frame(width: 8, height: 8)
                    Text(postureHeadline).font(.system(size: 10))
                }
            }
            Divider().overlay(Color.white.opacity(0.2))
            row("bolt.fill", "Intents", "\(state.intents)  (\(state.dominantDomain))")
            row("sparkles", "Fitness", String(format: "%.2f", state.fitness))
            row("gauge.medium", "Usage", state.usageLabel)
            row("arrow.right", "Next", state.priorityItem)
            Divider().overlay(Color.white.opacity(0.2))
            Text(postureFooter)
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).frame(width: 14)
            Text(label).foregroundStyle(.white.opacity(0.6)).frame(width: 58, alignment: .leading)
            Text(value).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
        }.font(.system(size: 11))
    }

    /// "[M-1] Blast-radius simulation" -> "M-1"
    private var shortPriority: String {
        let s = state.priorityItem
        if s.first == "[", let close = s.firstIndex(of: "]") {
            return String(s[s.index(after: s.startIndex)..<close])
        }
        return s
    }
}
