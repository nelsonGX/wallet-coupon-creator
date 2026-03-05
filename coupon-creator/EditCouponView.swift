//
//  EditCouponView.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI
import PassKit

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

    @State private var isSaving = false
    @State private var passToAdd: PKPass?
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
        _termsAndConditions = State(initialValue: coupon.termsAndConditions)
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

                Section("Icon") {
                    iconPickerSection
                }

                Section("Appearance") {
                    ColorPicker("Background Color", selection: backgroundColorBinding)
                    ColorPicker("Text Color", selection: foregroundColorBinding)
                    ColorPicker("Title Color", selection: labelColorBinding)
                }
            }
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
            .sheet(item: $passToAdd) { pass in
                WalletPassSheet(pass: pass) { _ in
                    passToAdd = nil
                    dismiss()
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { dismiss() }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
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
        updated.termsAndConditions = termsAndConditions
        store.updateCoupon(updated)

        isSaving = true
        Task {
            do {
                let pass = try await store.updateWalletPass(for: updated)
                passToAdd = pass
            } catch {
                errorMessage = "Saved locally. Server update failed: \(error.localizedDescription)"
                showError = true
            }
            isSaving = false
        }
    }
}
