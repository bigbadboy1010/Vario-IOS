
import SwiftUI

/// Placeholder Settings View to adjust sensitivity
struct SettingsView: View {
    @AppStorage("climbSensitivity") var climbSensitivity: Double = 0.1
    @AppStorage("sinkSensitivity") var sinkSensitivity: Double = 0.1

    var body: some View {
        Form {
            Section(header: Text("Empfindlichkeit")) {
                VStack(alignment: .leading) {
                    Text("Steigen: \(String(format: "%.2f", climbSensitivity)) m/s")
                    Slider(value: $climbSensitivity, in: 0...1, step: 0.05)
                }
                VStack(alignment: .leading) {
                    Text("Sinken: \(String(format: "%.2f", sinkSensitivity)) m/s")
                    Slider(value: $sinkSensitivity, in: 0...1, step: 0.05)
                }
            }
        }
        .navigationTitle("Einstellungen")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
