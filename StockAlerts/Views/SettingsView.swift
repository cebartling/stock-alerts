import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var engine: QuoteEngine
    @AppStorage("pollIntervalSeconds") private var pollIntervalSeconds: Int = 30
    @AppStorage("extendedHours") private var extendedHours: Bool = false

    @State private var apiKey: String = Secrets.finnhubKey
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var notifMessage: String = ""

    var body: some View {
        Form {
            Section("Finnhub") {
                SecureField("API key", text: $apiKey)
                HStack {
                    Button("Save") { Secrets.finnhubKey = apiKey }
                        .keyboardShortcut(.defaultAction)
                    Button("Clear") {
                        apiKey = ""
                        Secrets.finnhubKey = ""
                    }
                }
            }
            Section("Polling") {
                Stepper("Interval: \(pollIntervalSeconds)s",
                        value: $pollIntervalSeconds,
                        in: 10...300,
                        step: 5)
                .onChange(of: pollIntervalSeconds) { _, newValue in
                    engine.pollInterval = TimeInterval(newValue)
                }
                Toggle("Include extended hours (4:00–20:00 ET)", isOn: $extendedHours)
            }
            Section("Notifications") {
                Text("Status: \(statusText(notifStatus))")
                    .foregroundStyle(.secondary)
                if !notifMessage.isEmpty {
                    Text(notifMessage).font(.caption)
                }
                Button("Request permission") {
                    Task {
                        let granted = await NotificationAuthorizer.requestAuthorization()
                        notifMessage = granted ? "Granted." : "Denied — enable in System Settings."
                        notifStatus = await NotificationAuthorizer.currentStatus()
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 420)
        .task {
            notifStatus = await NotificationAuthorizer.currentStatus()
        }
    }

    private func statusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "not requested"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        case .provisional:   return "provisional"
        case .ephemeral:     return "ephemeral"
        @unknown default:    return "unknown"
        }
    }
}
