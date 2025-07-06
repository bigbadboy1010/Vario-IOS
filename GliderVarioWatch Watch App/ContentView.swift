import SwiftUI
import CoreMotion
import CoreLocation
import WatchKit
import AVFoundation

// MARK: - ToneGenerator
/// Generates simple sine‑wave beeps for the variometer on Apple Watch.
fileprivate final class ToneGenerator {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private let bufferFormat: AVAudioFormat

    init() {
        bufferFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
                                     channels: 1)!
        setupEngine()
    }

    private func setupEngine() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("AudioSession error: \(error)") }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: bufferFormat)

        do { try engine.start() } catch {
            print("Audio engine failed: \(error)")
        }
        player.play()
    }

    /// Plays a sine‑wave tone.
    func play(freq: Double, duration: Double = 0.15, amp: Double = 0.4) {
        let frames = Int(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: bufferFormat,
                                            frameCapacity: AVAudioFrameCount(frames)) else { return }
        buffer.frameLength = AVAudioFrameCount(frames)

        var theta = 0.0
        let delta = 2.0 * .pi * freq / sampleRate
        let ptr   = buffer.floatChannelData![0]

        for i in 0..<frames {
            ptr[i] = Float32(sin(theta) * amp)
            theta += delta
            if theta >= 2 * .pi { theta -= 2 * .pi }
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}

class MotionData: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager\(\)
    private let toneGenerator = ToneGenerator()
    private var lastBeep = Date(timeIntervalSince1970: 0)
    private var lastAltitude: Double?
    private var lastUpdateTime: Date?

    @Published var altitude: Double = 0.0
    @Published var variometer: Double = 0.0 {
        didSet {
            handleVariometerChange()
        }
    }
    @Published var speedInKmh: Int = 0
    @Published var isWarningActive: Bool = false

    override init() {
        super.init()
        startMotionUpdates()
        startLocationUpdates()
    }

    private func startMotionUpdates() {
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] (altitudeData, error) in
                guard let self = self, let altitudeData = altitudeData, error == nil else {
                    print("Altitude Update Error: \(error?.localizedDescription ?? "unknown error")")
                    return
                }

                let currentTime = Date()
                let currentAltitude = altitudeData.relativeAltitude.doubleValue

                DispatchQueue.main.async {
                    if let lastAltitude = self.lastAltitude, let lastUpdateTime = self.lastUpdateTime {
                        let timeInterval = currentTime.timeIntervalSince(lastUpdateTime)
                        if timeInterval > 0 {
                            self.variometer = (currentAltitude - lastAltitude) / timeInterval
                        }
                    }

                    self.lastAltitude = currentAltitude
                    self.lastUpdateTime = currentTime
                    self.altitude = currentAltitude
                }
            }
        }
    }

    private func startLocationUpdates() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let speed = location.speed > 0 ? location.speed : 0
            let speedInKmh = speed * 3.6
            DispatchQueue.main.async {
                self.speedInKmh = Int(round(speedInKmh))
            }
        }
    }

    private func handleVariometerChange() {
        if variometer > 0 {
            playTone(forIntensity: variometer)
            isWarningActive = false
        } else {
            playHaptic(forIntensity: abs(variometer))
            isWarningActive = variometer <= -3.0
        }
    }

    
    private func playTone(forIntensity intensity: Double) {
        guard intensity > 0.3 else { return }
        let now = Date()
        guard now.timeIntervalSince(lastBeep) > 0.2 else { return }
        lastBeep = now
        let freq = min(600 + 150 * intensity, 1_200)
        toneGenerator.play(freq: freq)
    }


    private func playHaptic(forIntensity intensity: Double) {
        let hapticType: WKHapticType = intensity > 1.0 ? .success : .failure
        WKInterfaceDevice.current().play(hapticType)
    }
}

struct ContentView: View {
    @ObservedObject var motionData = MotionData()

    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                Spacer()
                InfoText(label: "Vario", value: "\(String(format: "%.1f", motionData.variometer)) m/s", isWarning: motionData.isWarningActive)
                InfoText(label: "Höhe", value: "\(Int(motionData.altitude)) m")
                InfoText(label: "G.", value: "\(motionData.speedInKmh) km/h")
                Spacer()
            }
            .gesture(
                TapGesture(count: 3)
                    .onEnded { _ in
                        // Implementieren Sie hier Ihre Aktion bei dreifachem Tippen
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
