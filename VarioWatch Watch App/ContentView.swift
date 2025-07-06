import SwiftUI

struct ContentView: View {
    @ObservedObject var motionData = MotionData()

    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                Spacer()
                InfoText(label: "Vario", value: "\(String(format: "%.1f", motionData.variometer)) m/s", isWarning: motionData.isWarningActive)
                InfoText(label: "H", value: "\(Int(motionData.altitude)) m")
                InfoText(label: "G", value: "\(motionData.speedInKmh) km/h")
                Spacer()
            }
            .gesture(
                TapGesture(count: 3)
                    .onEnded { _ in
                        motionData.resetData()
                    }
            )
        }
    }
}

struct InfoText: View {
    var label: String
    var value: String
    var isWarning: Bool = false

    var body: some View {
        Text("\(label): \(value)")
            .font(.system(size: 29))
            .padding(5)
            .background(isWarning ? Color.red.opacity(0.5) : Color.black.opacity(0.5))
            .cornerRadius(8)
            .foregroundColor(.white)
            .padding(.bottom, 20)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
