//
//  CreateCouponView.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI
import PassKit
import PhotosUI
import UIKit

struct CreateCouponView: View {
    @Environment(CouponStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var discount = ""
    @State private var maxUse = 1
    @State private var isRechargeable = false
    @State private var keepAfterUsedUp = true
    @State private var hasExpiration = false
    @State private var expirationDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var organizationName = ""
    @State private var bgRed = 0.2
    @State private var bgGreen = 0.5
    @State private var bgBlue = 0.9
    @State private var fgRed = 1.0
    @State private var fgGreen = 1.0
    @State private var fgBlue = 1.0
    @State private var lbRed = 1.0
    @State private var lbGreen = 1.0
    @State private var lbBlue = 1.0
    @State private var category: CouponCategory = .other
    @State private var iconName = "tag.fill"
    @State private var termsAndConditions = ""
    @State private var showIconPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var iconImageData: Data?
    @State private var imageToCrop: UIImage?

    @State private var isCreating = false
    @State private var passToAdd: PKPass?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                // Live preview at the top
                Section {
                    couponPreview
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Category template picker
                Section("Choose a Template") {
                    categoryTemplatePicker
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)

                Section("Coupon Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    TextField("Discount (e.g. 20% OFF, $5 OFF)", text: $discount)
                    TextField("Organization / Store Name", text: $organizationName)
                    TextField("Terms & Conditions", text: $termsAndConditions, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Usage Settings") {
                    Stepper("Max Uses: \(maxUse)", value: $maxUse, in: 1...999)
                    Toggle("Rechargeable", isOn: $isRechargeable)
                    Toggle("Keep After All Used Up", isOn: $keepAfterUsedUp)
                }

                Section("Expiration") {
                    Toggle("Set Expiration Date", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Expires On", selection: $expirationDate, in: Date()..., displayedComponents: .date)
                    }
                }

                // Icon picker
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
            .navigationTitle("Create Coupon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            createCoupon()
                        }
                        .disabled(title.isEmpty)
                    }
                }
            }
            .disabled(isCreating)
            .sheet(item: $passToAdd) { pass in
                WalletPassSheet(pass: pass) { added in
                    passToAdd = nil
                    dismiss()
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: Binding(
                get: { imageToCrop != nil },
                set: { if !$0 { imageToCrop = nil } }
            )) {
                if let image = imageToCrop {
                    IconCropperView(image: image) { croppedData in
                        iconImageData = croppedData
                    }
                }
            }
        }
    }

    // MARK: - Category Template Picker

    private var categoryTemplatePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CouponCategory.allCases) { cat in
                    Button {
                        applyTemplate(cat)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: cat.defaultIcon)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(
                                            red: cat.defaultBackground.red,
                                            green: cat.defaultBackground.green,
                                            blue: cat.defaultBackground.blue
                                        ))
                                )
                                .foregroundStyle(.white)
                            Text(cat.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(category == cat ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(category == cat ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
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
            maxUse: maxUse,
            expirationDate: hasExpiration ? expirationDate : nil,
            organizationName: organizationName,
            backgroundColor: CouponColor(red: bgRed, green: bgGreen, blue: bgBlue),
            foregroundColor: CouponColor(red: fgRed, green: fgGreen, blue: fgBlue),
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
                    fgRed = Double(components[0])
                    fgGreen = Double(components[1])
                    fgBlue = Double(components[2])
                }
            }
        )
    }

    // MARK: - Actions

    private func applyTemplate(_ cat: CouponCategory) {
        withAnimation(.easeInOut(duration: 0.25)) {
            category = cat
            iconName = cat.defaultIcon
            bgRed = cat.defaultBackground.red
            bgGreen = cat.defaultBackground.green
            bgBlue = cat.defaultBackground.blue
            fgRed = 1.0
            fgGreen = 1.0
            fgBlue = 1.0
        }
    }

    private func createCoupon() {
        let coupon = Coupon(
            title: title,
            description: description,
            discount: discount,
            maxUse: maxUse,
            isRechargeable: isRechargeable,
            keepAfterUsedUp: keepAfterUsedUp,
            expirationDate: hasExpiration ? expirationDate : nil,
            organizationName: organizationName,
            backgroundColor: CouponColor(red: bgRed, green: bgGreen, blue: bgBlue),
            foregroundColor: CouponColor(red: fgRed, green: fgGreen, blue: fgBlue),
            category: category,
            iconName: iconName,
            iconImageData: iconImageData,
            termsAndConditions: termsAndConditions
        )
        store.addCoupon(coupon)

        isCreating = true
        Task {
            do {
                let pass = try await store.signWalletPass(for: coupon)
                passToAdd = pass
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isCreating = false
        }
    }
}
