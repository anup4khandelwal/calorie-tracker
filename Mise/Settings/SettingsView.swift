import SwiftUI

/// Settings sheet: identity, goals, and the two API keys (Keychain-backed).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var calorieGoal = 2200.0
    @State private var proteinGoal = 120.0
    @State private var anthropicKey = ""
    @State private var geminiKey = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    section("You") {
                        LabeledField(label: "Name") {
                            TextField("What should I call you?", text: $name)
                                .textInputAutocapitalization(.words)
                        }
                        GoalSlider(label: "Daily calories", value: $calorieGoal, range: 1200...4000, step: 50, unit: "kcal")
                        GoalSlider(label: "Daily protein", value: $proteinGoal, range: 40...300, step: 5, unit: "g")
                    }

                    section("Keys") {
                        LabeledField(label: "Anthropic API key", hint: "Powers the conversation — console.anthropic.com") {
                            SecureField("sk-ant-…", text: $anthropicKey)
                        }
                        LabeledField(label: "Gemini API key", hint: "Powers the food photography — aistudio.google.com (optional)") {
                            SecureField("AIza…", text: $geminiKey)
                        }
                    }

                    Text("Keys are stored in the iOS Keychain on this device only.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.creamFaint)
                }
                .padding(Theme.pagePadding)
            }
            .background(Theme.ink)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.saffron)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.ink)
        .onAppear(perform: load)
    }

    private func load() {
        let profile = model.store.profile()
        name = profile.name
        calorieGoal = profile.calorieGoal
        proteinGoal = profile.proteinGoal
        anthropicKey = KeyVault.get(.anthropic) ?? ""
        geminiKey = KeyVault.get(.gemini) ?? ""
    }

    private func save() {
        let profile = model.store.profile()
        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.calorieGoal = calorieGoal
        profile.proteinGoal = proteinGoal
        model.store.save()
        KeyVault.set(anthropicKey, for: .anthropic)
        KeyVault.set(geminiKey, for: .gemini)
        Haptics.shared.tick()
        dismiss()
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Overline(text: title, color: Theme.saffron.opacity(0.85))
            content()
        }
    }
}

// MARK: - Shared form pieces (used by Settings + Onboarding)

struct LabeledField<Field: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder var field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.creamDim)
            field
                .font(Theme.body)
                .foregroundStyle(Theme.cream)
                .tint(Theme.saffron)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.inkRaised)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        }
                }
            if let hint {
                Text(hint)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.creamFaint)
            }
        }
    }
}

struct GoalSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.creamDim)
                Spacer()
                Text("\(Int(value))")
                    .font(Theme.stat(20))
                    .foregroundStyle(Theme.cream)
                    .contentTransition(.numericText(value: value))
                Text(unit)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.creamFaint)
            }
            Slider(value: $value, in: range, step: step)
                .tint(Theme.saffron)
                .onChange(of: value) {
                    Haptics.shared.tick()
                }
        }
    }
}
