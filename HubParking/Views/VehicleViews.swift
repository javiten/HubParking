import SwiftUI

struct AirportSection: View {
    let airport: Airport
    let vehicles: [ParkedVehicle]
    let isExpanded: Bool
    let viewModel: ParkedVehiclesViewModel
    let onToggle: () -> Void
    
    var body: some View {
        Section {
            content
        } header: {
            header
        }
    }
    
    private var content: some View {
        Group {
            if isExpanded {
                ForEach(vehicles) { vehicle in
                    ParkedVehicleRow(vehicle: vehicle, viewModel: viewModel)
                }
            }
        }
    }
    
    private var header: some View {
        SectionHeaderView(
            title: airport.name,
            count: vehicles.count,
            isExpanded: isExpanded,
            action: onToggle
        )
    }
}
