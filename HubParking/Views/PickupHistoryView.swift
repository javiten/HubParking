import SwiftUI

struct PickupHistoryView: View {
    @EnvironmentObject private var viewModel: ParkedVehiclesViewModel
    @State private var search = ""
    @State private var location = "All"
    @State private var period = "All time"
    @State private var recordType = "Pickups"
    @State private var selected: ParkedVehicle?
    @State private var showClear = false
    private func recordedDate(_ record: ParkedVehicle) -> Date { record.createdAt ?? record.dateParked }
    private var filtered: [ParkedVehicle] {
        viewModel.pickupHistory.filter { record in
            let text = "\(record.vehicle.description) \(record.airportName) \((record.garageName ?? "").replacingOccurrences(of: "IBIS", with: "Ibis")) \(record.parkingSpot ?? "") \(record.notes ?? "") \(record.addedBy)"
            let days = period == "7 days" ? 7 : 30
            let dateMatches = period == "All time" || recordedDate(record) >= Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            return (recordType == "All" || (recordType == "Deleted" ? record.eventType == "deleted" : record.eventType != "deleted")) && (location == "All" || record.airportName.contains(location)) && dateMatches && (search.isEmpty || text.localizedCaseInsensitiveContains(search))
        }.sorted { recordedDate($0) > recordedDate($1) }
    }
    private var days: [Date] { Array(Set(filtered.map { Calendar.current.startOfDay(for: recordedDate($0)) })).sorted(by: >) }
    var body: some View {
        List {
            Section {
                Picker("Record Type", selection: $recordType) {
                    Text("Pickups").tag("Pickups")
                    Text("Deleted").tag("Deleted")
                    Text("All").tag("All")
                }.pickerStyle(.segmented)
                Picker("Location", selection: $location) {
                    ForEach(["All", "MIA", "FLL", "OFFICE"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)
                Picker("Period", selection: $period) {
                    ForEach(["All time", "7 days", "30 days"], id: \.self) { Text($0).tag($0) }
                }
                HStack {
                    Label("\(filtered.count) records", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Text("\(Set(filtered.map { $0.vehicleId }).count) vehicles").foregroundStyle(.secondary)
                }.font(.subheadline)
            }
            ForEach(days, id: \.self) { day in
                Section(day.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(filtered.filter { Calendar.current.isDate(recordedDate($0), inSameDayAs: day) }) { record in
                        Button { selected = record } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(record.vehicle.plate).font(.headline.monospaced()).foregroundStyle(.primary)
                                    Spacer()
                                    Text(recordedDate(record).formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                }
                                Label(record.eventType == "deleted" ? "Deleted" : "Picked up", systemImage: record.eventType == "deleted" ? "trash" : "car.fill")
                                    .font(.caption.weight(.semibold)).foregroundStyle(record.eventType == "deleted" ? .red : .green)
                                Text("\(record.vehicle.make) \(record.vehicle.model)").foregroundStyle(.primary)
                                Label("\(record.airportName) · \((record.garageName ?? "").replacingOccurrences(of: "IBIS", with: "Ibis")) \(record.parkingSpot ?? "")", systemImage: "mappin.and.ellipse")
                                    .font(.subheadline).foregroundStyle(.blue)
                                HStack {
                                    Label(record.addedBy, systemImage: "person")
                                    Spacer()
                                    if !record.photoPaths.isEmpty { Label("\(record.photoPaths.count)", systemImage: "photo") }
                                }.font(.caption).foregroundStyle(.secondary)
                                if let notes = record.notes, !notes.isEmpty { Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                            }.padding(.vertical, 6)
                        }
                    }
                }
            }
            if filtered.isEmpty { ContentUnavailableView("No History Found", systemImage: "clock", description: Text("Try another location, period or search.")) }
        }
        .toolbar { ToolbarItem(placement: .topBarLeading) { FloatingVehicleSearch(text: $search) } }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ParkingSettingsButton() } }
        .navigationTitle("History")
        .refreshable { await viewModel.loadParkingHistory() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await viewModel.loadParkingHistory() } }
                    Button("Clear All History", systemImage: "trash", role: .destructive) { showClear = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .confirmationDialog("Permanently clear all history?", isPresented: $showClear, titleVisibility: .visible) {
            Button("Clear All History", role: .destructive) { Task { await viewModel.clearPickupHistory() } }
        } message: { Text("This deletes all history, including records hidden by filters.") }
        .sheet(item: $selected) { record in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Action", value: record.eventType == "deleted" ? "Deleted parking card" : "Pickup")
                        LabeledContent("Recorded", value: recordedDate(record).formatted())
                        LabeledContent("Parked", value: record.dateParked.formatted())
                        LabeledContent("Team member", value: record.addedBy)
                        ParkedVehicleCard(parkedVehicle: record, showUndoButton: true, isHistoryView: true)
                    }.padding()
                }
                .navigationTitle("Parking Record").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selected = nil } } }
            }.environmentObject(viewModel)
        }
    }
}
