//
//  PlaceholderTabView.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import SwiftUI

struct PlaceholderTabView: View {
    let title: String
    let symbol: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.top, 22)

            Spacer()

            VStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(AppTheme.primaryGreen)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 95)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}
