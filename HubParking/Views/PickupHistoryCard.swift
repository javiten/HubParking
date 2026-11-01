import SwiftUI
import UIKit
import Foundation

struct PickupHistoryCard: View {
    let parkedVehicle: ParkedVehicle
    @State private var showPhotoModal = false
    @State private var vehicleImage: UIImage?
    @State private var isLoadingImage = false
    @State private var imageLoadTask: Task<Void, Never>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primary Info: Make Model + Plate
            Text("\(parkedVehicle.vehicle.make) \(parkedVehicle.vehicle.model) \(parkedVehicle.vehicle.plate)")
                .font(.system(size: 17, weight: .regular))
            
            // Location
            Text("\(parkedVehicle.garageName ?? "Unknown") \(parkedVehicle.parkingSpot ?? "")")
                .font(.system(size: 15))
                .foregroundColor(.blue)
            
            // Notes (if present)
            if let notes = parkedVehicle.notes, !notes.isEmpty {
                Text("Notes: \(notes)")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Time and Added By
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                Text(parkedVehicle.dateParked.formatted(date: .numeric, time: .shortened))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Picked up by \(parkedVehicle.addedBy)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                if let photoPath = parkedVehicle.photoPath, !photoPath.isEmpty {
                    Image(systemName: "photo.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if let photoPath = parkedVehicle.photoPath, !photoPath.isEmpty {
                Task {
                    await loadPhoto()
                    if vehicleImage != nil {
                        showPhotoModal = true
                    }
                }
            }
        }
        .sheet(isPresented: $showPhotoModal) {
            NavigationView {
                ZStack {
                    if isLoadingImage {
                        ProgressView("Loading image...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let image = vehicleImage {
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
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showPhotoModal = false
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isLoadingImage)
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
        }
        .onChange(of: showPhotoModal) { oldValue, newValue in
            if newValue {
                if vehicleImage == nil {
                    imageLoadTask?.cancel()
                    imageLoadTask = Task {
                        await loadPhoto()
                    }
                }
            } else {
                imageLoadTask?.cancel()
                vehicleImage = nil
            }
        }
        .onDisappear {
            imageLoadTask?.cancel()
            vehicleImage = nil
        }
        .onAppear {
            print("\n=== PickupHistoryCard Debug ===")
            print("Vehicle: \(parkedVehicle.vehicle.make) \(parkedVehicle.vehicle.model)")
            print("Notes: \(parkedVehicle.notes ?? "no notes")")
            print("Photo: \(parkedVehicle.photoPath ?? "no photo")")
        }
    }
    
    private func loadPhoto() async {
        isLoadingImage = true
        defer { isLoadingImage = false }
        
        guard let photoPath = parkedVehicle.photoPath else {
            print("loadPhoto: No photoPath available")
            return
        }
        
        print("loadPhoto: Attempting to download photo from path: \(photoPath)")
        
        do {
            // Use the new downloadPhoto method with authentication
            let imageData = try await SupabaseService.shared.downloadPhoto(path: photoPath)
            
            if let image = UIImage(data: imageData) {
                await MainActor.run {
                    self.vehicleImage = image
                    print("loadPhoto: Successfully loaded image with size: \(image.size)")
                }
            } else {
                print("loadPhoto: Failed to create UIImage from downloaded data")
            }
        } catch {
            print("loadPhoto: Error downloading photo: \(error)")
            
            // Check if it's a 404 error (file not found) by checking the error description
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("404") || errorDescription.contains("not found") || errorDescription.contains("object not found") {
                print("loadPhoto: Image file not found (404), this is a history record so no cleanup needed")
                return
            }
            
            // Fallback: try the old URL method
            print("loadPhoto: Trying fallback URL method...")
            if let photoURL = SupabaseService.shared.photoURL(path: photoPath) {
                print("loadPhoto: Fallback URL: \(photoURL)")
                
                do {
                    let (data, response) = try await URLSession.shared.data(from: photoURL)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("loadPhoto: HTTP Response Status: \(httpResponse.statusCode)")
                        print("loadPhoto: Data size received: \(data.count) bytes")
                        
                        if httpResponse.statusCode == 200 {
                            if let image = UIImage(data: data) {
                                await MainActor.run {
                                    self.vehicleImage = image
                                    print("loadPhoto: Successfully loaded image via fallback URL")
                                }
                            } else {
                                print("loadPhoto: Failed to create UIImage from fallback URL data")
                            }
                        } else if httpResponse.statusCode == 404 {
                            print("loadPhoto: Image not found via URL (404), this is a history record so no cleanup needed")
                        } else {
                            print("loadPhoto: HTTP error: \(httpResponse.statusCode)")
                        }
                    }
                } catch {
                    print("loadPhoto: Fallback URL request failed: \(error)")
                }
            }
        }
    }
} 