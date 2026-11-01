import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var pin = ""
    @State private var showingPIN = false
    @State private var enableBiometrics = false
    @FocusState private var isPinFieldFocused: Bool

    var body: some View {
        NavigationStack {
        GeometryReader { geometry in
            ZStack {
                Image("HubMiamiSplash")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()
                LinearGradient(colors: [.clear, .black.opacity(0.1), .black.opacity(0.9)],
                               startPoint: .center, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack {
                    Spacer(minLength: 24)
                    VStack(spacing: 16) {
                        Text("PARKING")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .tracking(6)
                            .foregroundStyle(.white.opacity(0.85))
                        if userManager.biometricEnabled && !showingPIN {
                            Button {
                                Task { await userManager.authenticateWithBiometrics() }
                            } label: {
                                Label("Enter with \(userManager.biometricName)", systemImage: "faceid")
                                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(userManager.biometricBusy)
                        }
                        if showingPIN {
                        Text("Welcome back")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        SecureField("Enter your PIN", text: $pin)
                            .keyboardType(.numberPad)
                            .textContentType(.password)
                            .focused($isPinFieldFocused)
                            .multilineTextAlignment(.center)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2)))
                            .accessibilityLabel("PIN")
                            if userManager.biometricAvailable {
                                Toggle("Enable \(userManager.biometricName) on this iPhone", isOn: $enableBiometrics)
                                    .font(.subheadline).foregroundStyle(.white).tint(.yellow)
                            }
                        }
                        Button {
                            if showingPIN {
                                userManager.authenticate(pin: pin, enableBiometrics: enableBiometrics)
                            } else {
                                showingPIN = true
                                isPinFieldFocused = true
                            }
                        } label: {
                            HStack {
                                Text(showingPIN ? "Let's park" : (userManager.biometricEnabled ? "Use PIN / Switch user" : "Enter")).font(.headline)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .foregroundStyle(.black)
                            .background(Color(red: 1, green: 0.81, blue: 0), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(showingPIN && pin.isEmpty)
                        .opacity(showingPIN && pin.isEmpty ? 0.6 : 1)
                        if let error = userManager.biometricError {
                            Text(error).font(.footnote).foregroundStyle(.white).multilineTextAlignment(.center)
                        }
                        if userManager.showLoginError {
                            Text("Incorrect PIN. Try again.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                    .frame(maxWidth: 390)
                    .padding(24)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isPinFieldFocused = false }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            guard userManager.biometricEnabled, userManager.shouldAutoAuthenticate else { return }
            userManager.shouldAutoAuthenticate = false
            await userManager.authenticateWithBiometrics()
            if !userManager.isAuthenticated {
                showingPIN = true
                isPinFieldFocused = true
            }
        }
        .onAppear {
            pin = ""
            userManager.showLoginError = false
        }
    }
}

#Preview {
    LoginView().environmentObject(UserManager()).environmentObject(ThemeManager())
}
