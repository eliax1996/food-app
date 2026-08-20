import Foundation
import SwiftUI

enum FoodToolsIntent {
    case barcode
    case customFood
}

enum BarcodeLookupFailure: Equatable {
    case invalid
    case notFound
    case incomplete
    case offline
    case unavailable
    case saveFailed
    case generic

    var title: String {
        switch self {
        case .invalid: "Check barcode"
        case .notFound: "Product not found"
        case .incomplete: "Product details incomplete"
        case .offline: "You’re offline"
        case .unavailable: "Lookup unavailable"
        case .saveFailed: "Couldn’t save product"
        case .generic: "Couldn’t look up product"
        }
    }

    var body: String {
        switch self {
        case .invalid: "Enter a barcode with 8 to 14 digits."
        case .notFound: "Try another barcode or create a custom food below."
        case .incomplete: "Calorie details are missing. You can create a custom food below."
        case .offline: "You can still create a custom food below. Reconnect, then try again."
        case .unavailable: "Open Food Facts is unavailable right now. Try again shortly."
        case .saveFailed: "Product was found, but could not be saved. Try again."
        case .generic: "Open Food Facts could not complete this lookup. Try again."
        }
    }

    var icon: String {
        switch self {
        case .invalid: "barcode"
        case .notFound: "magnifyingglass"
        case .incomplete: "list.bullet.clipboard"
        case .offline: "wifi.slash"
        case .unavailable: "clock"
        case .saveFailed: "tray.and.arrow.down"
        case .generic: "exclamationmark.circle"
        }
    }

    static func classify(_ error: any Error) -> BarcodeLookupFailure {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                    .cannotFindHost, .dataNotAllowed:
                return .offline
            case .timedOut:
                return .unavailable
            default:
                return .generic
            }
        }

        guard let fetchError = error as? FoodNutritionFetchError else {
            return .generic
        }
        switch fetchError {
        case .invalidBarcode:
            return .invalid
        case .timedOut, .serverError:
            return .unavailable
        case .invalidResponse:
            return .generic
        }
    }
}

struct FoodToolsView: View {
    private enum FocusedField: Hashable {
        case barcode
        case name
        case calories
        case serving
    }

    @FocusState private var focusedField: FocusedField?
    @State private var appliedInitialFocus = false

    @Binding var barcode: String
    @Binding var foodName: String
    @Binding var calories: Int
    @Binding var servingAmount: Double
    @Binding var carbohydrates: Double?
    @Binding var protein: Double?
    @Binding var fat: Double?
    @Binding var fiber: Double?

    let intent: FoodToolsIntent
    let isLookingUpBarcode: Bool
    let barcodeLookupFailure: BarcodeLookupFailure?
    let onBarcodeChanged: () -> Void
    let onDone: () -> Void
    let onLookupBarcode: () -> Void
    let onSaveFood: () -> Void

    private var normalizedBarcode: String {
        barcode.filter(\.isNumber)
    }

    private var canLookupBarcode: Bool {
        (8...14).contains(normalizedBarcode.count) && !isLookingUpBarcode
    }

    private var canSaveFood: Bool {
        !foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && CalorieCalculator.isValidCalories(calories)
            && servingAmount.isFinite
            && servingAmount > 0
            && [carbohydrates, protein, fat, fiber].allSatisfy {
                guard let value = $0 else { return true }
                return value.isFinite && value >= 0
            }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Barcode", text: $barcode)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .barcode)
                        .textContentType(.none)
                        .disabled(isLookingUpBarcode)
                        .accessibilityIdentifier("manual-barcode")
                        .onChange(of: barcode) { _, _ in
                            onBarcodeChanged()
                        }

                    if isLookingUpBarcode {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Looking up product")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Looking up product")
                        .accessibilityIdentifier("barcode-lookup-loading")
                    } else if let barcodeLookupFailure {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(barcodeLookupFailure.title)
                                    .font(.headline)
                                    .accessibilityIdentifier("barcode-lookup-failure-title")
                                Text(barcodeLookupFailure.body)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.primary.opacity(0.72))
                                    .accessibilityIdentifier("barcode-lookup-failure-message")
                            }
                        } icon: {
                            Image(systemName: barcodeLookupFailure.icon)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("barcode-lookup-failure")
                    }

                    Button {
                        onLookupBarcode()
                    } label: {
                        Label(
                            barcodeLookupFailure == nil ? "Look up product" : "Try lookup again",
                            systemImage: barcodeLookupFailure == nil ? "barcode.viewfinder" : "arrow.clockwise"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("barcode-lookup-button")
                    .foregroundStyle(
                        canLookupBarcode ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
                    )
                    .disabled(!canLookupBarcode)
                } header: {
                    Text("Barcode")
                } footer: {
                    Text("Enter 8 to 14 digits printed below the product barcode.")
                }

                Section {
                    LabeledContent("Name") {
                        TextField("Food name", text: $foodName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .name)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("custom-food-name")
                    }

                    LabeledContent("Calories") {
                        TextField("Calories", value: $calories, format: .number)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .calories)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Serving") {
                        HStack(spacing: 6) {
                            TextField(
                                "Grams",
                                value: $servingAmount,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .serving)
                            .multilineTextAlignment(.trailing)
                            Text("g")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        CustomFoodNutrientsEditor(
                            carbohydrates: $carbohydrates,
                            protein: $protein,
                            fat: $fat,
                            fiber: $fiber
                        )
                    } label: {
                        LabeledContent("Nutrients (optional)", value: nutrientSummary)
                    }
                    .accessibilityIdentifier("custom-food-nutrients")

                    Button("Save custom food", action: onSaveFood)
                        .disabled(!canSaveFood)
                } header: {
                    Text("Custom food")
                        .accessibilityIdentifier("custom-food-section-heading")
                } footer: {
                    Text("Enter a name and 0–\(CalorieCalculator.maximumCalories.formatted()) kcal for the serving amount shown above.")
                }
            }
            .navigationTitle("Food tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                    .accessibilityIdentifier("food-tools-done")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .accessibilityIdentifier("food-tools-keyboard-done")
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            guard !appliedInitialFocus else { return }
            appliedInitialFocus = true
            focusedField = intent == .barcode ? .barcode : .name
        }
    }

    private var nutrientSummary: String {
        let count = [carbohydrates, protein, fat, fiber].compactMap { $0 }.count
        return count == 0 ? "Not added" : "\(count) of 4 added"
    }
}

private struct CustomFoodNutrientsEditor: View {
    private enum FocusedField: Hashable {
        case carbohydrates
        case protein
        case fat
        case fiber
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusedField?

    @Binding private var carbohydrates: Double?
    @Binding private var protein: Double?
    @Binding private var fat: Double?
    @Binding private var fiber: Double?

    @State private var draftCarbohydrates: Double?
    @State private var draftProtein: Double?
    @State private var draftFat: Double?
    @State private var draftFiber: Double?

    init(
        carbohydrates: Binding<Double?>,
        protein: Binding<Double?>,
        fat: Binding<Double?>,
        fiber: Binding<Double?>
    ) {
        _carbohydrates = carbohydrates
        _protein = protein
        _fat = fat
        _fiber = fiber
        _draftCarbohydrates = State(initialValue: carbohydrates.wrappedValue)
        _draftProtein = State(initialValue: protein.wrappedValue)
        _draftFat = State(initialValue: fat.wrappedValue)
        _draftFiber = State(initialValue: fiber.wrappedValue)
    }

    var body: some View {
        Form {
            Section {
                nutrientField(
                    "Carbs",
                    value: $draftCarbohydrates,
                    identifier: "custom-food-carbohydrates",
                    field: .carbohydrates
                )
                nutrientField(
                    "Protein",
                    value: $draftProtein,
                    identifier: "custom-food-protein",
                    field: .protein
                )
                nutrientField(
                    "Fat",
                    value: $draftFat,
                    identifier: "custom-food-fat",
                    field: .fat
                )
                nutrientField(
                    "Fiber",
                    value: $draftFiber,
                    identifier: "custom-food-fiber",
                    field: .fiber
                )
            } footer: {
                Text("Values apply to the custom food serving. Tap Done to keep them, then save the custom food in Food tools. Leave unknown values blank.")
            }
        }
        .navigationTitle("Nutrients")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: saveDraft)
                    .accessibilityIdentifier("nutrient-editor-done")
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .accessibilityIdentifier("nutrient-editor-keyboard-done")
            }
        }
    }

    private func nutrientField(
        _ title: String,
        value: Binding<Double?>,
        identifier: String,
        field: FocusedField
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(
                    "Optional",
                    value: value,
                    format: .number.precision(.fractionLength(0...2))
                )
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 88, maxWidth: 140)
                .accessibilityLabel("\(title) grams per serving")
                .accessibilityIdentifier(identifier)

                Text("g")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveDraft() {
        carbohydrates = draftCarbohydrates
        protein = draftProtein
        fat = draftFat
        fiber = draftFiber
        focusedField = nil
        Task { @MainActor in
            // iOS 17 must process focus loss before navigation pops this editor.
            await Task.yield()
            dismiss()
        }
    }
}

#if DEBUG || RELEASE_VALIDATION
private struct PushedFoodToolsPreview<Destination: View>: View {
    @State private var path = [1]

    let destination: Destination

    init(@ViewBuilder destination: () -> Destination) {
        self.destination = destination()
    }

    var body: some View {
        NavigationStack(path: $path) {
            Color.clear
                .navigationTitle("Food tools")
                .navigationDestination(for: Int.self) { _ in
                    destination
                }
        }
    }
}

#Preview("Food tools") {
    FoodToolsView(
        barcode: .constant(""),
        foodName: .constant(""),
        calories: .constant(120),
        servingAmount: .constant(100),
        carbohydrates: .constant(nil),
        protein: .constant(nil),
        fat: .constant(nil),
        fiber: .constant(nil),
        intent: .barcode,
        isLookingUpBarcode: false,
        barcodeLookupFailure: nil,
        onBarcodeChanged: {},
        onDone: {},
        onLookupBarcode: {},
        onSaveFood: {}
    )
}

#Preview("Food tools offline") {
    FoodToolsView(
        barcode: .constant("99999999"),
        foodName: .constant(""),
        calories: .constant(120),
        servingAmount: .constant(100),
        carbohydrates: .constant(nil),
        protein: .constant(nil),
        fat: .constant(nil),
        fiber: .constant(nil),
        intent: .barcode,
        isLookingUpBarcode: false,
        barcodeLookupFailure: .offline,
        onBarcodeChanged: {},
        onDone: {},
        onLookupBarcode: {},
        onSaveFood: {}
    )
}

#Preview("Food tools loading") {
    FoodToolsView(
        barcode: .constant("11111111"),
        foodName: .constant(""),
        calories: .constant(120),
        servingAmount: .constant(100),
        carbohydrates: .constant(nil),
        protein: .constant(nil),
        fat: .constant(nil),
        fiber: .constant(nil),
        intent: .barcode,
        isLookingUpBarcode: true,
        barcodeLookupFailure: nil,
        onBarcodeChanged: {},
        onDone: {},
        onLookupBarcode: {},
        onSaveFood: {}
    )
}

#Preview("Custom food nutrients") {
    PushedFoodToolsPreview {
        CustomFoodNutrientsEditor(
            carbohydrates: .constant(15),
            protein: .constant(10),
            fat: .constant(2),
            fiber: .constant(4)
        )
    }
}
#endif
