//
//  LocationPickerView.swift
//  coupon-creator
//

import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss

    /// The location being edited, or nil for a new location.
    var existing: PassLocation?
    /// Called when the user confirms a location.
    var onSave: (PassLocation) -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pinCoordinate: CLLocationCoordinate2D?
    @State private var relevantText: String = ""
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search for a place", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit {
                            performSearch()
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)

                ZStack {
                    // Map
                    MapReader { proxy in
                        Map(position: $cameraPosition) {
                            if let pin = pinCoordinate {
                                Marker("Selected", coordinate: pin)
                                    .tint(.red)
                            }
                        }
                        .onTapGesture { screenPoint in
                            if let coordinate = proxy.convert(screenPoint, from: .local) {
                                withAnimation {
                                    pinCoordinate = coordinate
                                }
                            }
                        }
                    }

                    // Search results overlay
                    if !searchResults.isEmpty {
                        VStack {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(searchResults, id: \.self) { item in
                                        Button {
                                            selectSearchResult(item)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name ?? "Unknown")
                                                    .font(.body)
                                                    .foregroundStyle(.primary)
                                                if let subtitle = item.placemark.formattedAddress {
                                                    Text(subtitle)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        Divider()
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 4)
                            .padding(8)

                            Spacer()
                        }
                    }
                }

                // Bottom panel: coordinate info + relevant text
                VStack(spacing: 10) {
                    if let pin = pinCoordinate {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                            Text(String(format: "%.5f, %.5f", pin.latitude, pin.longitude))
                                .font(.footnote.monospaced())
                            Spacer()
                        }
                    } else {
                        HStack {
                            Image(systemName: "hand.tap")
                                .foregroundStyle(.secondary)
                            Text("Tap the map or search to pick a location")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    TextField("Lock screen text (optional)", text: $relevantText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle(existing == nil ? "Add Location" : "Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard let pin = pinCoordinate else { return }
                        let location = PassLocation(
                            id: existing?.id ?? UUID(),
                            latitude: pin.latitude,
                            longitude: pin.longitude,
                            relevantText: relevantText
                        )
                        onSave(location)
                        dismiss()
                    }
                    .disabled(pinCoordinate == nil)
                }
            }
            .onAppear {
                if let existing {
                    let coord = CLLocationCoordinate2D(latitude: existing.latitude, longitude: existing.longitude)
                    pinCoordinate = coord
                    relevantText = existing.relevantText
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        latitudinalMeters: 1000,
                        longitudinalMeters: 1000
                    ))
                }
            }
        }
    }

    // MARK: - Search

    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed

        Task {
            let search = MKLocalSearch(request: request)
            if let response = try? await search.start() {
                searchResults = response.mapItems
            }
            isSearching = false
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        pinCoordinate = coord
        if relevantText.isEmpty, let name = item.name {
            relevantText = name
        }
        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        ))
        searchResults = []
        searchText = item.name ?? ""
    }
}

// MARK: - Helpers

private extension CLPlacemark {
    var formattedAddress: String? {
        [locality, administrativeArea, country]
            .compactMap { $0 }
            .joined(separator: ", ")
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
