import Foundation
import AVFoundation

/// Synthesises short beeps (positive climb) and smooth descending glissandi (sink)
/// for the variometer. Public API is limited to `update(climbRate:)` and `stop()`.
final class AudioService {

    // MARK: – Singleton
    static let shared = AudioService()
    private init() {
        setupAudioComponents()
    }

    // MARK: – Public API ------------------------------------------------------

    /// Call regularly (e.g. every 100 ms) with the current `climbRate` in m/s.
    /// Positive rates -> beep, negative rates -> smooth sink tone.
    func update(climbRate: Double) {
        guard isEngineRunning else { return }
        
        let climbSens = UserDefaults.standard.double(forKey: "climbSensitivity")
        let sinkSens  = UserDefaults.standard.double(forKey: "sinkSensitivity")
        guard abs(climbRate) > max(climbSens, sinkSens) else { return }

        // debounce
        let now = Date()
        guard now.timeIntervalSince(lastBeep) > 0.20 else { return }
        lastBeep = now

        if climbRate >= climbSens {
            // Rising: single beep, higher pitch with stronger climb.
            let freq = min(600 + 150 * climbRate, 1_200)
            playTone(freq: freq, duration: 0.15, amplitude: 0.5)
        } else {
            // Sink: smooth descending glissando in one buffer
            let startFreq = 600.0
            let endFreq   = max(150, 600 + 150 * climbRate)
            playGlissandoSmooth(startFreq: startFreq,
                                endFreq:   endFreq,
                                duration:  0.30,
                                amplitude: 0.5)
        }
    }

    /// Stop playback and tear down the engine (e.g. when the view disappears).
    func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if self.player.isPlaying {
                self.player.stop()
            }
            
            if self.engine.isRunning {
                self.engine.stop()
            }
            
            self.isEngineRunning = false
            
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
        }
    }
    
    /// Start or restart the audio engine
    func start() {
        queue.async { [weak self] in
            self?.setupEngine()
        }
    }

    // MARK: – Private implementation ----------------------------------------

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let queue = DispatchQueue(label: "com.glidertracker.audio", qos: .userInitiated)
    
    // Consistent format throughout
    private let sampleRate: Double = 48_000.0
    private lazy var audioFormat: AVAudioFormat = {
        // Use standard PCM format with consistent settings
        return AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }()
    
    private var lastBeep: Date = .distantPast
    private var isEngineRunning: Bool = false

    /// Setup audio format and initial components
    private func setupAudioComponents() {
        queue.async { [weak self] in
            self?.setupEngine()
        }
    }

    /// Configure AVAudioEngine with proper error handling
    private func setupEngine() {
        do {
            // Configure audio session first
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(sampleRate)
            try session.setPreferredIOBufferDuration(0.005) // Low latency
            try session.setActive(true)

            // Reset engine if needed
            if engine.isRunning {
                engine.stop()
                engine.reset()
            }

            // Setup audio graph
            engine.attach(player)
            
            // Use consistent format throughout
            engine.connect(player, to: engine.mainMixerNode, format: audioFormat)
            
            // Prepare and start engine
            engine.prepare()
            try engine.start()
            
            if !player.isPlaying {
                player.play()
            }
            
            isEngineRunning = true
            print("Audio engine started successfully")
            
        } catch {
            print("Audio engine setup failed: \(error)")
            isEngineRunning = false
        }
    }

    /// Render a sine tone into a PCM buffer and schedule it on the player.
    private func playTone(freq: Double, duration: Double, amplitude: Double) {
        queue.async { [weak self] in
            guard let self = self, self.isEngineRunning else { return }
            
            let frameCount = Int(duration * self.sampleRate)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: self.audioFormat,
                                                frameCapacity: AVAudioFrameCount(frameCount)) else {
                print("Failed to create audio buffer")
                return
            }
            
            buffer.frameLength = AVAudioFrameCount(frameCount)

            var theta = 0.0
            let delta = 2.0 * Double.pi * freq / self.sampleRate

            // Use consistent channel count from our format
            for ch in 0..<Int(self.audioFormat.channelCount) {
                guard let ptr = buffer.floatChannelData?[ch] else { continue }
                theta = 0.0
                for i in 0..<frameCount {
                    ptr[i] = Float32(sin(theta) * amplitude)
                    theta += delta
                    if theta >= 2 * .pi { theta -= 2 * .pi }
                }
            }

            // Ensure engine is still running before scheduling
            if self.engine.isRunning && self.player.isPlaying {
                self.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            } else {
                // Try to restart if needed
                self.setupEngine()
                if self.engine.isRunning {
                    self.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
                }
            }
        }
    }

    /// Single-Buffer Glissando: glatter Übergang von startFreq -> endFreq
    /// durch exponentielle Interpolation und lineares Fade-Out.
    private func playGlissandoSmooth(startFreq: Double,
                                     endFreq: Double,
                                     duration: Double,
                                     amplitude: Double) {
        queue.async { [weak self] in
            guard let self = self, self.isEngineRunning else { return }
            
            let frameCount = Int(duration * self.sampleRate)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: self.audioFormat,
                                                frameCapacity: AVAudioFrameCount(frameCount)) else {
                print("Failed to create glissando buffer")
                return
            }
            
            buffer.frameLength = AVAudioFrameCount(frameCount)

            var phase: Double = 0
            let twoPi = 2.0 * Double.pi

            // Use consistent channel count from our format
            for ch in 0..<Int(self.audioFormat.channelCount) {
                guard let ptr = buffer.floatChannelData?[ch] else { continue }
                phase = 0
                for i in 0..<frameCount {
                    let t = Double(i) / Double(frameCount - 1)        // 0…1
                    let freq = startFreq * pow(endFreq / startFreq, t)
                    let delta = twoPi * freq / self.sampleRate
                    let env = amplitude * (1.0 - t)                  // lineares Fade-Out

                    ptr[i] = Float32(sin(phase) * env)
                    phase += delta
                    if phase >= twoPi { phase -= twoPi }
                }
            }

            // Ensure engine is still running before scheduling
            if self.engine.isRunning && self.player.isPlaying {
                self.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            } else {
                // Try to restart if needed
                self.setupEngine()
                if self.engine.isRunning {
                    self.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
                }
            }
        }
    }
}
