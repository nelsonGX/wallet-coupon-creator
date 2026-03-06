//
//  ContentView.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCreateSheet = false
    @State private var selectedTab = 0
    @State private var isScannerEnabled = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("My Coupons", systemImage: "ticket", value: 0) {
                MyCouponsView(showCreateSheet: $showCreateSheet)
            }
            Tab("Scan", systemImage: "qrcode.viewfinder", value: 1) {
                ScannerView(isScannerEnabled: isScannerEnabled)
            }
        }
        .onChange(of: selectedTab) { updateScannerEnabled() }
        .onChange(of: scenePhase) { updateScannerEnabled() }
        .sheet(isPresented: $showCreateSheet) {
            CreateCouponView()
        }
    }

    private func updateScannerEnabled() {
        isScannerEnabled = selectedTab == 1 && scenePhase == .active
    }
}

// MARK: - My Coupons Tab

struct MyCouponsView: View {
    @Environment(CouponStore.self) private var store
    @Binding var showCreateSheet: Bool

    @State private var isSelecting = false
    @State private var selectedCouponIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if store.coupons.isEmpty {
                    emptyState
                } else {
                    couponList
                }
            }
            .navigationTitle("My Coupons")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.coupons.isEmpty {
                        Button(isSelecting ? "Done" : "Select") {
                            withAnimation {
                                isSelecting.toggle()
                                if !isSelecting {
                                    selectedCouponIDs.removeAll()
                                }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isSelecting {
                        Button {
                            if selectedCouponIDs.count == store.coupons.count {
                                selectedCouponIDs.removeAll()
                            } else {
                                selectedCouponIDs = Set(store.coupons.map(\.id))
                            }
                        } label: {
                            Text(selectedCouponIDs.count == store.coupons.count ? "Deselect All" : "Select All")
                        }
                    } else {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if isSelecting && !selectedCouponIDs.isEmpty {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete \(selectedCouponIDs.count) Coupon\(selectedCouponIDs.count == 1 ? "" : "s")", systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
            }
            .confirmationDialog(
                "Delete \(selectedCouponIDs.count) Coupon\(selectedCouponIDs.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    store.deleteCoupons(withIDs: selectedCouponIDs)
                    selectedCouponIDs.removeAll()
                    if store.coupons.isEmpty {
                        isSelecting = false
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Coupons", systemImage: "ticket")
        } description: {
            Text("Create your first coupon to get started.")
        } actions: {
            Button("Create Coupon") {
                showCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var couponList: some View {
        List {
            ForEach(store.coupons) { coupon in
                if isSelecting {
                    Button {
                        toggleSelection(coupon.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedCouponIDs.contains(coupon.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedCouponIDs.contains(coupon.id) ? Color.accentColor : Color.secondary)
                            CouponCardView(coupon: coupon)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    NavigationLink(destination: CouponDetailView(coupon: coupon)) {
                        CouponCardView(coupon: coupon)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .onDelete { offsets in
                if !isSelecting {
                    store.deleteCoupons(at: offsets)
                }
            }
        }
        .listStyle(.plain)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedCouponIDs.contains(id) {
            selectedCouponIDs.remove(id)
        } else {
            selectedCouponIDs.insert(id)
        }
    }
}

#Preview {
    ContentView()
        .environment(CouponStore())
}
