
import SwiftUI

struct InstrumentHUD: View {
    @ObservedObject var vm: GliderTrackerViewModel

    var body: some View {
        HStack {
            // ALT
            VStack(alignment: .leading, spacing: 2) {
                Text("ALT")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f m", vm.currentAltitude))
                    .font(.title2.monospacedDigit())
                    .bold()
            }

            Spacer()

            // VAR
            VStack(spacing: 2) {
                Text("VAR")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%+.1f m/s", vm.climbRate))
                    .font(.title3.monospacedDigit())
                    .bold()
                    .foregroundColor(vm.climbRate >= 0 ? .green : .red)
            }

            Spacer()

            // SPD
            VStack(alignment: .trailing, spacing: 2) {
                Text("SPD")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f km/h", vm.indicatedAirspeed))
                    .font(.title2.monospacedDigit())
                    .bold()
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .allowsHitTesting(false)
    }
}
