//
//  Coupon.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import Foundation

enum CouponCategory: String, Codable, CaseIterable, Identifiable {
    case food
    case shopping
    case travel
    case entertainment
    case health
    case services
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: "Food & Drink"
        case .shopping: "Shopping"
        case .travel: "Travel"
        case .entertainment: "Entertainment"
        case .health: "Health & Beauty"
        case .services: "Services"
        case .other: "Other"
        }
    }

    var defaultIcon: String {
        switch self {
        case .food: "fork.knife"
        case .shopping: "bag.fill"
        case .travel: "airplane"
        case .entertainment: "film"
        case .health: "heart.fill"
        case .services: "wrench.and.screwdriver.fill"
        case .other: "tag.fill"
        }
    }

    var defaultBackground: CouponColor {
        switch self {
        case .food: CouponColor(red: 0.90, green: 0.30, blue: 0.25)
        case .shopping: CouponColor(red: 0.20, green: 0.50, blue: 0.90)
        case .travel: CouponColor(red: 0.15, green: 0.70, blue: 0.55)
        case .entertainment: CouponColor(red: 0.60, green: 0.30, blue: 0.80)
        case .health: CouponColor(red: 0.95, green: 0.50, blue: 0.60)
        case .services: CouponColor(red: 0.35, green: 0.35, blue: 0.40)
        case .other: CouponColor(red: 0.20, green: 0.50, blue: 0.90)
        }
    }

    /// Suggested SF Symbol icons for this category
    var suggestedIcons: [String] {
        switch self {
        case .food:
            ["fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "birthday.cake.fill", "mug.fill", "wineglass.fill"]
        case .shopping:
            ["bag.fill", "cart.fill", "storefront.fill", "tshirt.fill", "gift.fill", "creditcard.fill"]
        case .travel:
            ["airplane", "car.fill", "bus.fill", "ferry.fill", "globe.americas.fill", "map.fill"]
        case .entertainment:
            ["film", "gamecontroller.fill", "music.note", "theatermasks.fill", "popcorn.fill", "party.popper.fill"]
        case .health:
            ["heart.fill", "cross.fill", "leaf.fill", "figure.run", "sparkles", "hands.sparkles.fill"]
        case .services:
            ["wrench.and.screwdriver.fill", "hammer.fill", "paintbrush.fill", "scissors", "washer.fill", "house.fill"]
        case .other:
            ["tag.fill", "star.fill", "bolt.fill", "flame.fill", "diamond.fill", "square.grid.2x2.fill"]
        }
    }
}

struct Coupon: Identifiable, Codable {
    var id: UUID
    var title: String
    var description: String
    var discount: String
    var useCount: Int
    var maxUse: Int
    var isRechargeable: Bool
    var keepAfterUsedUp: Bool
    var createdDate: Date
    var expirationDate: Date?
    var organizationName: String
    var backgroundColor: CouponColor
    var foregroundColor: CouponColor
    var labelColor: CouponColor
    var category: CouponCategory
    var iconName: String
    var termsAndConditions: String

    var isFullyUsed: Bool {
        useCount >= maxUse
    }

    var remainingUses: Int {
        max(0, maxUse - useCount)
    }

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
    }

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        discount: String = "",
        useCount: Int = 0,
        maxUse: Int = 1,
        isRechargeable: Bool = false,
        keepAfterUsedUp: Bool = true,
        createdDate: Date = Date(),
        expirationDate: Date? = nil,
        organizationName: String = "",
        backgroundColor: CouponColor = CouponColor(red: 0.2, green: 0.5, blue: 0.9),
        foregroundColor: CouponColor = CouponColor(red: 1, green: 1, blue: 1),
        labelColor: CouponColor = CouponColor(red: 1, green: 1, blue: 1),
        category: CouponCategory = .other,
        iconName: String = "tag.fill",
        termsAndConditions: String = ""
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.discount = discount
        self.useCount = useCount
        self.maxUse = maxUse
        self.isRechargeable = isRechargeable
        self.keepAfterUsedUp = keepAfterUsedUp
        self.createdDate = createdDate
        self.expirationDate = expirationDate
        self.organizationName = organizationName
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.labelColor = labelColor
        self.category = category
        self.iconName = iconName
        self.termsAndConditions = termsAndConditions
    }

    // Custom decoding to handle existing coupons without new fields
    enum CodingKeys: String, CodingKey {
        case id, title, description, discount, useCount, maxUse
        case isRechargeable, keepAfterUsedUp, createdDate, expirationDate
        case organizationName, backgroundColor, foregroundColor, labelColor
        case category, iconName, termsAndConditions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        discount = try container.decode(String.self, forKey: .discount)
        useCount = try container.decode(Int.self, forKey: .useCount)
        maxUse = try container.decode(Int.self, forKey: .maxUse)
        isRechargeable = try container.decode(Bool.self, forKey: .isRechargeable)
        keepAfterUsedUp = try container.decode(Bool.self, forKey: .keepAfterUsedUp)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
        organizationName = try container.decode(String.self, forKey: .organizationName)
        backgroundColor = try container.decode(CouponColor.self, forKey: .backgroundColor)
        foregroundColor = try container.decode(CouponColor.self, forKey: .foregroundColor)
        labelColor = try container.decode(CouponColor.self, forKey: .labelColor)
        category = try container.decodeIfPresent(CouponCategory.self, forKey: .category) ?? .other
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "tag.fill"
        termsAndConditions = try container.decodeIfPresent(String.self, forKey: .termsAndConditions) ?? ""
    }
}

struct CouponColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
}


