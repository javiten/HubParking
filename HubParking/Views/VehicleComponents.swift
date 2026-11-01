import SwiftUI

struct ParkedVehicleRow: View {
    let vehicle: ParkedVehicle
    let viewModel: ParkedVehiclesViewModel
    @State private var isProcessing = false
    @State private var deletionError: String?
    @EnvironmentObject private var userManager: UserManager
    
    var body: some View {
        ParkedVehicleCard(
            parkedVehicle: vehicle,
            showUndoButton: false,
            isHistoryView: false
        )
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .disabled(isProcessing)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button { deleteCard() } label: {
                    Label("Delete", systemImage: "trash")
                }.tint(.red)
            }
            .alert("Could Not Delete Card", isPresented: Binding(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) {
                Button("OK") { deletionError = nil }
            } message: { Text(deletionError ?? "") }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) {
                pickupVehicle()
            } label: {
                Label("Pick Up", systemImage: "car.fill")
            }
            .tint(.green)
        }
    }
    
    private func deleteCard() {
        guard !isProcessing else { return }
        guard let actor = userManager.currentUser?.name, !actor.isEmpty else {
            deletionError = "Please sign in again before deleting a parking card."
            return
        }
        Task { @MainActor in
            isProcessing = true
            defer { isProcessing = false }
            do { try await viewModel.deleteParkingCard(vehicle, actor: actor) }
            catch { deletionError = error.localizedDescription }
        }
    }

    private func pickupVehicle() {
            Task {
                isProcessing = true
            await viewModel.pickupVehicle(vehicle, pickedUpBy: userManager.currentUser?.name ?? "")
                isProcessing = false
        }
    }
}
