import SwiftUI

/// First run: set the table. Name, goals, keys — then straight into today.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var calorieGoal = 2200.0
    @State private var proteinGoal = 120.0
    @State private var anthropicKey = ""
    @State private var openAIKey = ""
    @State private var geminiKey = ""

    private var canStart: Bool {
        !anthropicKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 10) {
                        Overline(text: "MISE · EN PLACE")
                        Text("Everything\nin its place.")
                            .font(Theme.masthead(42))
                            .foregroundStyle(Theme.cream)
                        Text("Tell Mise what you eat like you'd text a friend. It does the numbers, plates the pictures, and keeps the record.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.creamDim)
                            .lineSpacing(3)
                    }
                    .padding(.top, 36)

                    LabeledField(label: "Your name") {
                        TextField("Optional — Mise will ask anyway", text: $name)
                            .textInputAutocapitalization(.words)
                    }

                    GoalSlider(label: "Daily calories", value: $calorieGoal, range: 1200...4000, step: 50, unit: "kcal")
                    GoalSlider(label: "Daily protein", value: $proteinGoal, range: 40...300, step: 5, unit: "g")

                    VStack(alignment: .leading, spacing: 16) {
                        Overline(text: "Keys", color: Theme.saffron.opacity(0.85))
                        LabeledField(label: "Anthropic API key", hint: "Required — the conversation runs on Claude. console.anthropic.com") {
                            SecureField("sk-ant-…", text: $anthropicKey)
                        }
                        LabeledField(label: "OpenAI API key", hint: "Recommended — cutout plate photography with real transparency. platform.openai.com") {
                            SecureField("sk-…", text: $openAIKey)
                        }
                        LabeledField(label: "Gemini API key", hint: "Optional fallback photography. aistudio.google.com") {
                            SecureField("AIza…", text: $geminiKey)
                        }
                    }

                    Button(action: start) {
                        Text("Set the table")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(canStart ? Theme.ink : Theme.creamFaint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(canStart ? Theme.saffron : Theme.inkHigh)
                            }
                            .shadow(color: canStart ? Theme.saffron.opacity(0.35) : .clear, radius: 14, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStart)
                    .animation(Motion.snap, value: canStart)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 26)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func start() {
        let profile = model.store.profile()
        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.calorieGoal = calorieGoal
        profile.proteinGoal = proteinGoal
        profile.onboarded = true
        model.store.save()
        KeyVault.set(anthropicKey, for: .anthropic)
        KeyVault.set(openAIKey, for: .openai)
        KeyVault.set(geminiKey, for: .gemini)
        Haptics.shared.plated()
        dismiss()
    }
}
