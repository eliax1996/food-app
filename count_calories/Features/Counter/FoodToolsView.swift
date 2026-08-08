import SwiftUI

struct FoodToolsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var barcode: String
    @Binding var foodName: String
    @Binding var calories: Int
    @Binding var servingAmount: Double

    let isLookingUpBarcode: Bool
    let onLookupBarcode: () -> Void
    let onSaveFood: () -> Void

    private var normalizedBarcode: String {
        barcode.filter(\.isNumber)
    }

    private var canLookupBarcode: Bool {
        normalizedBarcode.count >= 8 && !isLookingUpBarcode
    }

    private var canSaveFood: Bool {
        !foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && calories >= 0
            && servingAmount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Barcode", text: $barcode)
                        .keyboardType(.numberPad)
                        .textContentType(.none)
                        .accessibilityIdentifier("manual-barcode")

                    Button {
                        onLookupBarcode()
                    } label: {
                        Label("Look up product", systemImage: "barcode.viewfinder")
                    }
                    .foregroundStyle(
                        canLookupBarcode ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
                    )
                    .disabled(!canLookupBarcode)

                    if isLookingUpBarcode {
                        ProgressView("Looking up product")
                    }
                } header: {
                    Text("Barcode")
                } footer: {
                    Text("Enter at least 8 digits printed below product barcode.")
                }

                Section {
                    TextField("Food name", text: $foodName)
                        .textInputAutocapitalization(.words)

                    LabeledContent("Calories") {
                        TextField("Calories", value: $calories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 72)
                    }

                    LabeledContent("Serving") {
                        HStack(spacing: 6) {
                            TextField(
                                "Grams",
                                value: $servingAmount,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 72)
                            Text("g")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Save custom food", action: onSaveFood)
                        .disabled(!canSaveFood)
                } header: {
                    Text("Custom food")
                } footer: {
                    Text("Calories are for the serving amount shown above.")
                }
            }
            .navigationTitle("Food tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#if DEBUG
#Preview("Food tools") {
    FoodToolsView(
        barcode: .constant(""),
        foodName: .constant(""),
        calories: .constant(120),
        servingAmount: .constant(100),
        isLookingUpBarcode: false,
        onLookupBarcode: {},
        onSaveFood: {}
    )
}
#endif
