import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var viewModel: ParkedVehiclesViewModel
    
    @State private var searchText = ""
    @State private var showAddVehicleLocation = false
    @State private var showPickupHistory = false
    @State private var showAirTagAssignment = false
    @State private var showHelp = false
    @State private var showAbout = false
    @State private var showSettings = false
    @State private var isMenuOpen = false
    @State private var expandedAirports: Set<String> = []
    @State private var selectedTab = 0
    @State private var homePath: [String] = []
    @State private var isRefreshing = false
    @State private var hasLoaded = false

    var filteredVehicles: [ParkedVehicle] {
        if searchText.isEmpty {
            return viewModel.parkedVehicles
        }
        return viewModel.parkedVehicles.filter { vehicle in
            vehicle.vehicle.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedVehicles: [(Airport, [ParkedVehicle])] {
        let grouped = Dictionary(grouping: filteredVehicles) { vehicle in
            // Standardize airport names
            if vehicle.airportName.contains("FLL") {
                return Airport(name: "FLL Airport", garages: [])
            } else if vehicle.airportName.contains("MIA") {
                return Airport(name: "MIA Airport", garages: [])
            } else {
                return Airport(name: vehicle.airportName, garages: [])
            }
        }
        
        return grouped.map { ($0.key, $0.value) }
            .sorted { $0.0.name < $1.0.name }
    }

    var body: some View {
        VStack(spacing: 0) {
        ZStack {
            // Home Tab
            NavigationStack(path: $homePath) {
                VStack {
                    Group {
                        if viewModel.isLoading && viewModel.parkedVehicles.isEmpty {
                            ProgressView("Loading vehicles...")
                        } else {
                            if searchText.isEmpty {
                                GeometryReader { geometry in
                                    VStack(spacing: 12) {
                                        airportTile(code: "MIA", title: "Miami")
                                        airportTile(code: "FLL", title: "Fort Lauderdale")
                                        airportTile(code: "OFFICE", title: "Office")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 12)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                }
                            } else {
                                List {
                                    ForEach(groupedVehicles, id: \.0.name) { airport, vehicles in
                                        Section(airport.name) {
                                            ForEach(vehicles) { vehicle in
                                                ParkedVehicleRow(vehicle: vehicle, viewModel: viewModel)
                                            }
                                        }
                                    }
                                }.listStyle(.insetGrouped).refreshable { await refresh() }
                            }

                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        FloatingVehicleSearch(text: $searchText)
                    }
                }
                .background(Color(.systemGroupedBackground))
                .toolbar { ToolbarItem(placement: .topBarTrailing) { ParkingSettingsButton() } }
                .navigationDestination(for: String.self) { code in
                    ParkingLocationList(initialCode: code)
                }
                .navigationTitle("HUB Parking App")
                .navigationBarTitleDisplayMode(.inline)
                .task {
                    if !hasLoaded {
                        print("Initial load of vehicles...")
                        await refresh()
                        hasLoaded = true
                    }
                }
            }
            .opacity(selectedTab == 0 ? 1 : 0)
            .allowsHitTesting(selectedTab == 0)
            .accessibilityHidden(selectedTab != 0)
            .zIndex(selectedTab == 0 ? 1 : 0)
            
            // History Tab
            NavigationStack {
                PickupHistoryView()
            }
            .opacity(selectedTab == 1 ? 1 : 0)
            .allowsHitTesting(selectedTab == 1)
            .accessibilityHidden(selectedTab != 1)
            .zIndex(selectedTab == 1 ? 1 : 0)
            
            // Add Tab
            NavigationStack {
                AddVehicleLocationView(viewModel: viewModel)
                    .environmentObject(userManager)
                    .environmentObject(themeManager)
            }
            .opacity(selectedTab == 2 ? 1 : 0)
            .allowsHitTesting(selectedTab == 2)
            .accessibilityHidden(selectedTab != 2)
            .zIndex(selectedTab == 2 ? 1 : 0)
            
            NavigationStack {
                VehicleListView()
            }
            .opacity(selectedTab == 3 ? 1 : 0)
            .allowsHitTesting(selectedTab == 3)
            .accessibilityHidden(selectedTab != 3)
            .zIndex(selectedTab == 3 ? 1 : 0)

            // AirTag Tab
            NavigationStack {
                AirTagAssignmentView()
            }
            .opacity(selectedTab == 4 ? 1 : 0)
            .allowsHitTesting(selectedTab == 4)
            .accessibilityHidden(selectedTab != 4)
            .zIndex(selectedTab == 4 ? 1 : 0)
            

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()

            HStack(spacing: 0) {
                navigationButton("Home", icon: "house.fill", tab: 0)
                navigationButton("History", icon: "clock.fill", tab: 1)
                addNavigationButton
                navigationButton("Vehicles", icon: "car.2.fill", tab: 3)
                navigationButton("AirTag", icon: "location.circle.fill", tab: 4)
            }
            .frame(height: 50)
            .padding(.top, 2)
            .padding(.bottom, 0)
            .background {
                Color(.systemBackground)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .overlay(alignment: .top) { Divider() }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onChange(of: selectedTab) { _, tab in
            if tab == 0 { homePath.removeAll() }
        }
        .environment(\.openParkingSettings, { showSettings = true })
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(userManager)
                .environmentObject(themeManager)
                .environmentObject(viewModel)
        }
        .environment(\.selectedTab, selectedTab)
        .environment(\.selectedTabBinding, $selectedTab)
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .overlay(alignment: .top) {
            if viewModel.isOffline {
                VStack {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("Offline Mode")
                        if !viewModel.offlineQueue.isEmpty {
                            Text("(\(viewModel.offlineQueue.count) pending)")
                        }
                    }
                    .padding(8)
                    .background(Color(.systemYellow).opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .animation(.default, value: viewModel.isOffline)
            }
        }
    }
    
    private var addNavigationButton: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            selectedTab = 2
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.accentColor.gradient, in: Circle())
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 4))
                    .shadow(color: Color.accentColor.opacity(0.25), radius: 7, y: 3)
                Text("Add").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selectedTab == 2 ? Color.accentColor : .secondary)
            }
            .offset(y: -12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add parking")
        .accessibilityAddTraits(selectedTab == 2 ? .isSelected : [])
    }

    private func navigationButton(_ title: String, icon: String, tab: Int) -> some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            if tab == 0 { homePath.removeAll() }
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 21))
                Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    private func airportVehicles(_ code: String) -> [ParkedVehicle] {
        viewModel.parkedVehicles.filter { $0.airportName.contains(code) }
    }

    private func airportTile(code: String, title: String) -> some View {
        NavigationLink(value: code) {
            HStack(spacing: 20) {
                Image(systemName: code == "OFFICE" ? "building.2.fill" : "airplane.departure")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 60)
                VStack(alignment: .leading, spacing: 6) {
                    Text(code).font(.title.bold()).foregroundStyle(.primary)
                    Text(title).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(airportVehicles(code).count) parked").font(.subheadline.weight(.medium)).foregroundStyle(.blue)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(airportVehicles(code).count) parked vehicles")
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            try await viewModel.refreshData()
        } catch {
            print("Error refreshing: \(error)")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search vehicles...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct BottomBarButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
    }
}

// Update environment keys
private struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

private struct SelectedTabBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Int> = .constant(0)
}

extension EnvironmentValues {
    var selectedTab: Int {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
    
    var selectedTabBinding: Binding<Int> {
        get { self[SelectedTabBindingKey.self] }
        set { self[SelectedTabBindingKey.self] = newValue }
    }
}

#Preview {
    ContentView()
        .environmentObject(UserManager())
        .environmentObject(ThemeManager())
        .environmentObject(ParkedVehiclesViewModel())
} 
struct ParkingLocationList: View {
    @EnvironmentObject private var viewModel: ParkedVehiclesViewModel
    @State private var code: String
    @State private var search = ""
    init(initialCode: String) { _code = State(initialValue: initialCode) }
    private var vehicles: [ParkedVehicle] { viewModel.parkedVehicles.filter {
        $0.airportName.contains(code) && (search.isEmpty || $0.vehicle.description.localizedCaseInsensitiveContains(search))
    } }
    var body: some View {
        VStack(spacing: 0) {
            Picker("Location", selection: $code) {
                Text("MIA").tag("MIA")
                Text("FLL").tag("FLL")
                Text("OFFICE").tag("OFFICE")
            }.pickerStyle(.segmented).padding()
            List(vehicles) { vehicle in ParkedVehicleRow(vehicle: vehicle, viewModel: viewModel) }
                .listStyle(.plain)
                .overlay {
                    if vehicles.isEmpty { ContentUnavailableView("No Parked Vehicles", systemImage: "car.fill") }
                }
                .refreshable { await viewModel.loadVehicles(force: true) }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ParkingSettingsButton() } }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                FloatingVehicleSearch(text: $search)
            }
        }
        .navigationTitle(code)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OpenParkingSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}
extension EnvironmentValues {
    var openParkingSettings: () -> Void {
        get { self[OpenParkingSettingsKey.self] }
        set { self[OpenParkingSettingsKey.self] = newValue }
    }
}
struct ParkingSettingsButton: View {
    @Environment(\.openParkingSettings) private var open
    var body: some View {
        Button(action: open) { Image(systemName: "gearshape") }
            .accessibilityLabel("Settings")
    }
}

struct FloatingVehicleSearch: View {
    @Binding var text: String
    @State private var expanded = false
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 10) {
            if expanded {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search vehicles…", text: $text)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { focused = false }
                Button {
                    text = ""; focused = false
                    withAnimation(.easeInOut(duration: 0.2)) { expanded = false }
                } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .accessibilityLabel("Close search")
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded = true }
                    focused = true
                } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                }.accessibilityLabel("Search vehicles")
            }
        }
        .padding(expanded ? 12 : 0)
        .frame(width: expanded ? 200 : 44, height: 44)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}
