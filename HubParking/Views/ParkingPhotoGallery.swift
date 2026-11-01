import SwiftUI

struct ParkingPhotoGallery: View {
    let paths: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var selected = 0
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if paths.isEmpty {
                    ContentUnavailableView("No Photos", systemImage: "photo")
                } else {
                    TabView(selection: $selected) {
                        ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                            ParkingGalleryImage(path: path).tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    Text("\(selected + 1) / \(paths.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    if paths.count > 1 {
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                                        Button { withAnimation { selected = index } } label: {
                                            ParkingGalleryImage(path: path)
                                                .frame(width: 64, height: 64).clipped()
                                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected == index ? Color.accentColor : .clear, lineWidth: 3))
                                        }.id(index).accessibilityLabel("Photo \(index + 1)")
                                    }
                                }.padding()
                            }
                            .onChange(of: selected) { _, value in withAnimation { proxy.scrollTo(value, anchor: .center) } }
                        }.frame(height: 90)
                    }
                }
            }
            .navigationTitle("Parking Photos").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct ParkingGalleryImage: View {
    let path: String
    @State private var image: UIImage?
    @State private var failed = false
    @State private var retry = 0
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else if failed {
                Button { failed = false; retry += 1 } label: { Label("Retry photo", systemImage: "arrow.clockwise") }
            } else { ProgressView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: retry) {
            do {
                let data = try await SupabaseService.shared.downloadPhoto(path: path)
                guard let decoded = UIImage(data: data) else { failed = true; return }
                image = decoded
            } catch { if !Task.isCancelled { failed = true } }
        }
    }
}
