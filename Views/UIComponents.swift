
import SwiftUI

// MARK: - Animated Loading States

/// Skeleton loading view for checkpoints
struct CheckpointSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    // Title skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)
                        .shimmer(isAnimating: isAnimating)
                    
                    // Description skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 12)
                        .frame(width: 200)
                        .shimmer(isAnimating: isAnimating)
                    
                    // Segmented control skeleton
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 32)
                        .shimmer(isAnimating: isAnimating)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
        .onAppear { isAnimating = true }
    }
}

/// Shimmer modifier for loading animation
struct ShimmerModifier: ViewModifier {
    let isAnimating: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.5), location: 0.5),
                            .init(color: .clear, location: 1),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                    .animation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                }
            )
            .mask(content)
    }
}

extension View {
    func shimmer(isAnimating: Bool) -> some View {
        modifier(ShimmerModifier(isAnimating: isAnimating))
    }
}

// MARK: - Success/Error Animations

/// Animated checkmark for successful operations
struct SuccessCheckmark: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 100, height: 100)
                .scaleEffect(animate ? 1.0 : 0.0)
            
            Image(systemName: "checkmark")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(animate ? 1.0 : 0.0)
                .rotationEffect(.degrees(animate ? 0 : -90))
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animate = true
            }
        }
    }
}

/// Animated error indicator
struct ErrorIndicator: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 100, height: 100)
            
            Image(systemName: "xmark")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(animate ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animate = true
            }
        }
    }
}

// MARK: - Enhanced Buttons

/// Primary action button with loading state
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1.0)
    }
}

/// Secondary button style
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Status Badges

/// Criticality badge with icon
struct CriticalityBadge: View {
    let level: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(level)
        }
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var icon: String {
        switch level.lowercased() {
        case "høy": return "exclamationmark.3"
        case "middels": return "exclamationmark.2"
        case "lav": return "exclamationmark"
        default: return "info.circle"
        }
    }
    
    private var color: Color {
        switch level.lowercased() {
        case "høy": return .red
        case "middels": return .orange
        case "lav": return .yellow
        default: return .gray
        }
    }
}

/// Equipment category badge with gradient
struct CategoryBadge: View {
    let category: EquipmentCategory
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
            Text(category.rawValue)
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [categoryColor, categoryColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(8)
    }
    
    private var categoryColor: Color {
        switch category {
        case .hvac: return .blue
        case .plumbing: return .cyan
        case .electrical: return .yellow
        case .fire: return .red
        case .access: return .green
        case .heating: return .orange
        case .cooling: return .indigo
        case .control: return .purple
        case .other: return .gray
        }
    }
}

// MARK: - Empty States

/// Empty state view for when no data is available
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Haptic Feedback

enum HapticType {
    case success
    case error
    case warning
    case selection
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
}

func triggerHaptic(_ type: HapticType) {
    switch type {
    case .success:
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    case .error:
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    case .warning:
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    case .selection:
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    case .impact(let style):
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

#Preview("Skeleton") {
    CheckpointSkeletonView()
        .padding()
}

#Preview("Success") {
    SuccessCheckmark()
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "checklist",
        title: "Ingen sjekklister",
        message: "Start med å skanne utstyr for å generere en sjekkliste",
        actionTitle: "Skann nå"
    ) {
        print("Scan tapped")
    }
}
