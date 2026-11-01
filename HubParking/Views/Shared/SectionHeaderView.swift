import SwiftUI

struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Explicitly prevent any state changes
            .opacity(1.0)
            .scaleEffect(1.0)
    }
}

struct SectionHeaderView: View {
    let title: String
    let count: Int
    let isExpanded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(count)")
                    .foregroundColor(.white)
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.white)
                    .font(.caption)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color(.systemGray3))
            .cornerRadius(8)
        }
        .buttonStyle(NoHighlightButtonStyle())
    }
}

#Preview {
    SectionHeaderView(
        title: "FLL Airport",
        count: 5,
        isExpanded: true
    ) {
        print("Tapped")
    }
    .padding()
} 