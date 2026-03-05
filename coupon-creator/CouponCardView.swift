//
//  CouponCardView.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI

struct CouponCardView: View {
    let coupon: Coupon

    private var fgColor: Color {
        Color(red: coupon.foregroundColor.red, green: coupon.foregroundColor.green, blue: coupon.foregroundColor.blue)
    }

    private var bgColor: Color {
        Color(red: coupon.backgroundColor.red, green: coupon.backgroundColor.green, blue: coupon.backgroundColor.blue)
    }
    
    private var lgColor: Color {
        Color(red: coupon.labelColor.red, green: coupon.labelColor.green, blue: coupon.labelColor.blue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Category icon
                Image(systemName: coupon.iconName)
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    if !coupon.organizationName.isEmpty {
                        Text(coupon.organizationName.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .opacity(0.8)
                    }
                    Text(coupon.title)
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Spacer()
                if !coupon.discount.isEmpty {
                    Text(coupon.discount)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            if !coupon.description.isEmpty {
                Text(coupon.description)
                    .font(.caption)
                    .opacity(0.8)
            }

            Divider()
                .overlay(fgColor.opacity(0.3))

            HStack(spacing: 6) {
                Label("\(coupon.useCount)/\(coupon.maxUse) used", systemImage: "ticket")
                    .font(.caption)

                Spacer()

                // Category badge
                Text(coupon.category.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())

                if coupon.isRechargeable {
                    Label("Rechargeable", systemImage: "arrow.circlepath")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                }

                if coupon.isExpired {
                    Text("EXPIRED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.4))
                        .clipShape(Capsule())
                } else if coupon.isFullyUsed {
                    Text("USED UP")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.7))
                        .clipShape(Capsule())
                }
            }

            // Expiration date row
            if let expDate = coupon.expirationDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("Expires \(expDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .opacity(0.8)
                }
            }
        }
        .padding()
        .foregroundStyle(fgColor)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(bgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
