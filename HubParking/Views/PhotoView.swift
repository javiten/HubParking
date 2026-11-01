import SwiftUI

struct PhotoView: View {
    let url: String
    @State private var image: UIImage?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading image...")
                } else if let image = image {
                    GeometryReader { geometry in
                        ScrollView {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geometry.size.width)
                                .frame(minHeight: geometry.size.height)
                        }
                        .scrollDisabled(true)
                    }
                } else {
                    ContentUnavailableView("Failed to load image", 
                        systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadImage()
        }
        .interactiveDismissDisabled(isLoading)
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }
    
    private func loadImage() async {
        isLoading = true
        if let photoURL = SupabaseService.shared.photoURL(path: url) {
            do {
                let (data, _) = try await URLSession.shared.data(from: photoURL)
                if let loadedImage = UIImage(data: data) {
                    image = loadedImage
                }
            } catch {
                print("Error loading image: \(error)")
            }
        }
        isLoading = false
    }
} 