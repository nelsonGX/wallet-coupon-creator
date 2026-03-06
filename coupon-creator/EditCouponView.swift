//
//  EditCouponView.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI
import PhotosUI
import UIKit

struct EditCouponView: View {
    @Environment(CouponStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let coupon: Coupon

    @State private var title: String
    @State private var description: String
    @State private var discount: String
    @State private var maxUse: Int
    @State private var useCount: Int
    @State private var isRechargeable: Bool
    @State private var keepAfterUsedUp: Bool
    @State private var hasExpiration: Bool
    @State private var expirationDate: Date
    @State private var organizationName: String
    @State private var bgRed: Double
    @State private var bgGreen: Double
    @State private var bgBlue: Double
    @State private var fgRed: Double
    @State private var fgGreen: Double
    @State private var fgBlue: Double
    @State private var lbRed: Double
    @State private var lbGreen: Double
    @State private var lbBlue: Double
    @State private var category: CouponCategory
    @State private var iconName: String
    @State private var termsAndConditions: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var iconImageData: Data?
    @State private var imageToCrop: UIImage?

    // Lock screen fields
    @State private var hasRelevantDate: Bool
    @State private var relevantDate: Date
    @State private var locations: [PassLocation]
    @State private var ibeacons: [PassiBeacon]
    @State private var locationToEdit: PassLocation?
    @State private var showLocationPicker = false

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(coupon: Coupon) {
        self.coupon = coupon
        _title = State(initialValue: coupon.title)
        _description = State(initialValue: coupon.description)
        _discount = State(initialValue: coupon.discount)
        _maxUse = State(initialValue: coupon.maxUse)
        _useCount = State(initialValue: coupon.useCount)
        _isRechargeable = State(initialValue: coupon.isRechargeable)
        _keepAfterUsedUp = State(initialValue: coupon.keepAfterUsedUp)
        _hasExpiration = State(initialValue: coupon.expirationDate != nil)
        _expirationDate = State(initialValue: coupon.expirationDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
        _organizationName = State(initialValue: coupon.organizationName)
        _bgRed = State(initialValue: coupon.backgroundColor.red)
        _bgGreen = State(initialValue: coupon.backgroundColor.green)
        _bgBlue = State(initialValue: coupon.backgroundColor.blue)
        _fgRed = State(initialValue: coupon.foregroundColor.red)
        _fgGreen = State(initialValue: coupon.foregroundColor.green)
        _fgBlue = State(initialValue: coupon.foregroundColor.blue)
        _lbRed = State(initialValue: coupon.labelColor.red)
        _lbGreen = State(initialValue: coupon.labelColor.green)
        _lbBlue = State(initialValue: coupon.labelColor.blue)
        _category = State(initialValue: coupon.category)
        _iconName = State(initialValue: coupon.iconName)
        _iconImageData = State(initialValue: coupon.iconImageData)
        _termsAndConditions = State(initialValue: coupon.termsAndConditions)
        _hasRelevantDate = State(initialValue: coupon.relevantDate != nil)
        _relevantDate = State(initialValue: coupon.relevantDate ?? Date())
        _locations = State(initialValue: coupon.locations)
        _ibeacons = State(initialValue: coupon.ibeacons)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Live preview
                Section {
                    couponPreview
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Coupon Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    TextField("Discount", text: $discount)
                    TextField("Organization Name", text: $organizationName)
                    TextField("Terms & Conditions", text: $termsAndConditions, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(CouponCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.defaultIcon)
                                .tag(cat)
                        }
                    }
                }

                Section("Usage Settings") {
                    Stepper("Max Uses: \(maxUse)", value: $maxUse, in: 1...999)
                    Stepper("Current Uses: \(useCount)", value: $useCount, in: 0...maxUse)
                    Toggle("Rechargeable", isOn: $isRechargeable)
                    Toggle("Keep After All Used Up", isOn: $keepAfterUsedUp)
                }

                Section("Expiration") {
                    Toggle("Set Expiration Date", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Expires On", selection: $expirationDate, displayedComponents: .date)
                    }
                }

                lockScreenSections

                Section("Icon") {
                    iconPickerSection

                    // Custom icon upload
                    HStack {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Upload Custom Icon", systemImage: "photo.on.rectangle")
                        }
                        Spacer()
                        if let iconImageData, let uiImage = UIImage(data: iconImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if iconImageData != nil {
                        Button("Remove Custom Icon", role: .destructive) {
                            iconImageData = nil
                            selectedPhotoItem = nil
                        }
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            imageToCrop = uiImage
                        }
                    }
                }

                Section("Appearance") {
                    ColorPicker("Background Color", selection: backgroundColorBinding)
                    ColorPicker("Text Color", selection: foregroundColorBinding)
                    ColorPicker("Title Color", selection: labelColorBinding)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Coupon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            saveCoupon()
                        }
                        .disabled(title.isEmpty)
                    }
                }
            }
            .disabled(isSaving)
            .alert("Error", isPresented: $showError) {
                Button("OK") { dismiss() }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(existing: locationToEdit) { saved in
                    if let index = locations.firstIndex(where: { $0.id == saved.id }) {
                        locations[index] = saved
                    } else {
                        locations.append(saved)
                    }
                }
            }
        }
    }

    // MARK: - Lock Screen Sections

    @ViewBuilder
    private var lockScreenSections: some View {
        Section {
            Toggle("Show on Lock Screen at Date", isOn: $hasRelevantDate)
            if hasRelevantDate {
                DatePicker("Date & Time", selection: $relevantDate, displayedComponents: [.date, .hourAndMinute])
            }
        } header: {
            Text("Lock Screen — Relevant Date")
        } footer: {
            Text("The pass will appear on the lock screen at this time.")
        }

        Section {
            ForEach(locations) { loc in
                Button {
                    locationToEdit = loc
                    showLocationPicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.4f, %.4f", loc.latitude, loc.longitude))
                                .font(.footnote.monospaced())
                            if !loc.relevantText.isEmpty {
                                Text(loc.relevantText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                locations.remove(atOffsets: offsets)
            }

            if locations.count < 10 {
                Button {
                    locationToEdit = nil
                    showLocationPicker = true
                } label: {
                    Label("Add Location", systemImage: "mappin.and.ellipse")
                }
            }
        } header: {
            Text("Lock Screen — Locations")
        } footer: {
            Text("Pass appears when within ~100 m of a location. Max 10.")
        }

        Section {
            ForEach($ibeacons) { $beacon in
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Proximity UUID", text: $beacon.proximityUUID)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    HStack {
                        Text("Major")
                            .foregroundStyle(.secondary)
                        TextField("Optional", value: $beacon.major, format: .number)
                            .keyboardType(.numberPad)
                        Text("Minor")
                            .foregroundStyle(.secondary)
                        TextField("Optional", value: $beacon.minor, format: .number)
                            .keyboardType(.numberPad)
                    }
                    TextField("Lock screen text (optional)", text: $beacon.relevantText)
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                ibeacons.remove(atOffsets: offsets)
            }

            if ibeacons.count < 10 {
                Button {
                    ibeacons.append(PassiBeacon(proximityUUID: "", relevantText: ""))
                } label: {
                    Label("Add iBeacon", systemImage: "sensor.tag.radiowaves.forward")
                }
            }
        } header: {
            Text("Lock Screen — iBeacons")
        } footer: {
            Text("Pass appears when a matching Bluetooth iBeacon is detected. Max 10.")
        }
    }

    // MARK: - Icon Picker

    private var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Selected:")
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(Color(red: bgRed, green: bgGreen, blue: bgBlue))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(category.suggestedIcons, id: \.self) { icon in
                    Button {
                        iconName = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(iconName == icon
                                        ? Color(red: bgRed, green: bgGreen, blue: bgBlue)
                                        : Color(.systemGray5))
                            )
                            .foregroundStyle(iconName == icon ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Preview

    private var couponPreview: some View {
        CouponCardView(coupon: Coupon(
            title: title.isEmpty ? "Sample Coupon" : title,
            description: description,
            discount: discount.isEmpty ? "Discount" : discount,
            useCount: useCount,
            maxUse: maxUse,
            expirationDate: hasExpiration ? expirationDate : nil,
            organizationName: organizationName,
            backgroundColor: CouponColor(red: bgRed, green: bgGreen, blue: bgBlue),
            foregroundColor: CouponColor(red: fgRed, green: fgGreen, blue: fgBlue),
            labelColor: CouponColor(red: lbRed, green: lbGreen, blue: lbBlue),
            category: category,
            iconName: iconName
        ))
    }

    // MARK: - Color Bindings

    private var backgroundColorBinding: Binding<Color> {
        Binding(
            get: { Color(red: bgRed, green: bgGreen, blue: bgBlue) },
            set: { newColor in
                if let components = newColor.cgColor?.components, components.count >= 3 {
                    bgRed = Double(components[0])
                    bgGreen = Double(components[1])
                    bgBlue = Double(components[2])
                }
            }
        )
    }

    private var foregroundColorBinding: Binding<Color> {
        Binding(
            get: { Color(red: fgRed, green: fgGreen, blue: fgBlue) },
            set: { newColor in
                if let components = newColor.cgColor?.components, components.count >= 3 {
                    fgRed = Double(components[0])
                    fgGreen = Double(components[1])
                    fgBlue = Double(components[2])
                }
            }
        )
    }
    
    private var labelColorBinding: Binding<Color> {
        Binding(
            get: { Color(red: lbRed, green: lbGreen, blue: lbBlue) },
            set: { newColor in
                if let components = newColor.cgColor?.components, components.count >= 3 {
                    lbRed = Double(components[0])
                    lbGreen = Double(components[1])
                    lbBlue = Double(components[2])
                }
            }
        )
    }

    // MARK: - Save

    private func saveCoupon() {
        var updated = coupon
        updated.title = title
        updated.description = description
        updated.discount = discount
        updated.maxUse = maxUse
        updated.useCount = useCount
        updated.isRechargeable = isRechargeable
        updated.keepAfterUsedUp = keepAfterUsedUp
        updated.expirationDate = hasExpiration ? expirationDate : nil
        updated.organizationName = organizationName
        updated.backgroundColor = CouponColor(red: bgRed, green: bgGreen, blue: bgBlue)
        updated.foregroundColor = CouponColor(red: fgRed, green: fgGreen, blue: fgBlue)
        updated.labelColor = CouponColor(red: lbRed, green: lbGreen, blue: lbBlue)
        updated.category = category
        updated.iconName = iconName
        updated.iconImageData = iconImageData
        updated.termsAndConditions = termsAndConditions
        updated.relevantDate = hasRelevantDate ? relevantDate : nil
        updated.locations = locations
        updated.ibeacons = ibeacons
        store.updateCoupon(updated)

        isSaving = true
        Task {
            do {
                _ = try await store.updateWalletPass(for: updated)
                dismiss()
            } catch {
                errorMessage = "Saved locally. Server update failed: \(error.localizedDescription)"
                showError = true
            }
            isSaving = false
        }
    }
}
