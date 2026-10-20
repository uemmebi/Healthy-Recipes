//
//  GroceryListView.swift
//  Healthy Recipes
//
//  Created by Umberto Alinei on 19/10/2026.
//

import SwiftUI
import SwiftData

struct GroceryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.addedAt, order: .forward) private var groceries: [GroceryItem]

    var body: some View {
        List {
            if groceries.isEmpty {
                ContentUnavailableView("Your list is empty", systemImage: "cart",
                    description: Text("Open a recipe and add its ingredients here."))
                    .listRowBackground(Color.clear)
                    .padding(.top, 50)
            } else {
                ForEach(groceries) { item in
                    Button {
                        item.checked.toggle()
                        try? modelContext.save()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 23))
                                .foregroundStyle(AppTheme.primaryGreen)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .strikethrough(item.checked)
                                    .foregroundStyle(item.checked ? AppTheme.secondaryText : AppTheme.primaryText)
                                Text(item.recipeTitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                            Text("\(QuantityText.format(item.quantity)) \(item.unit)")
                                .font(.system(size: 15, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.primaryGreen)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Groceries")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !groceries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 75) }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(groceries[index]) }
        try? modelContext.save()
    }
}
