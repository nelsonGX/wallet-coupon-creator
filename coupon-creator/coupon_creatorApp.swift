//
//  coupon_creatorApp.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI

@main
struct coupon_creatorApp: App {
    @State private var couponStore = CouponStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(couponStore)
        }
    }
}
