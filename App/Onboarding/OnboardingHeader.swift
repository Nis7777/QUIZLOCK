import SwiftUI

/// Back button (top left) with an optional centred step indicator.
struct OnboardingHeader: View {
    var onBack: (() -> Void)?
    var steps: Int = 0
    var current: Int = 0

    var body: some View {
        ZStack {
            if steps > 0 {
                PageDots(count: steps, index: current)
            }
            HStack {
                if let onBack {
                    BackButton(action: onBack)
                }
                Spacer()
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}
