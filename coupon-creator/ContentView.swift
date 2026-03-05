//
//  ContentView.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI

struct ContentView: View {
    @State private var showCreateSheet = false

    var body: some View {
        TabView {
            Tab("My Coupons", systemImage: "ticket") {
                MyCouponsView(showCreateSheet: $showCreateSheet)
            }
            Tab("Scan", systemImage: "qrcode.viewfinder") {
                ScannerView()
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCouponView()
        }
    }
}

// MARK: - My Coupons Tab

struct MyCouponsView: View {
    @Environment(CouponStore.self) private var store
    @Binding var showCreateSheet: Bool

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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
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
                NavigationLink(destination: CouponDetailView(coupon: coupon)) {
                    CouponCardView(coupon: coupon)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete { offsets in
                store.deleteCoupons(at: offsets)
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environment(CouponStore())
}
