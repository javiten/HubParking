import SwiftUI

struct MapPinView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            Image(systemName: "triangle.fill")
                .font(.caption)
                .foregroundColor(.accentColor)
                .offset(y: -3)
        }
    }
} 