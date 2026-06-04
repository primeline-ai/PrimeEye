import AVFoundation
import Vision
import CoreGraphics
import QuartzCore
import PrimeEyeKit

/// Owns the camera + Vision body-pose pipeline. Runs Vision at ~3fps on a background
/// queue and emits classified `PostureState` samples on the main queue.
///
/// Privacy (spec §7): frames are processed in memory and discarded immediately; only the
/// derived metrics (two floats) ever leave this object. Nothing is written to disk.
///
/// All mutable detector state (`baseline`, `thresholds`, throttle clock) is touched only on
/// `videoQueue`, so there is no cross-thread data race. Callers set the baseline via
/// `setBaseline(_:thresholds:)`, which hops onto that queue.
final class PostureMonitor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let videoQueue = DispatchQueue(label: "cc.primeline.primeeye.posture")
    private let request = VNDetectHumanBodyPoseRequest()

    private let minInterval: CFTimeInterval = 1.0 / 3.0   // ~3 fps throttle
    private let minConfidence: Float = 0.3

    // videoQueue-only state (never touched off the videoQueue → no locks needed)
    private var lastProcessed: CFTimeInterval = 0
    private var baseline: Baseline?
    private var thresholds: PostureThresholds = .default
    private var sessionConfigured = false
    private var _onSample: (@MainActor (PostureState, SlouchMetrics?) -> Void)?

    /// Register the per-frame callback. Delivered on the MAIN ACTOR (so consumers can touch
    /// UI/AppState directly); the backing store is videoQueue-isolated to avoid a data race
    /// with the capture thread (RC High-1). Safe to call from any thread.
    func setOnSample(_ callback: @escaping @MainActor (PostureState, SlouchMetrics?) -> Void) {
        videoQueue.async { [weak self] in self?._onSample = callback }
    }

    /// Update the calibrated reference. Safe to call from the main thread.
    func setBaseline(_ baseline: Baseline?, thresholds: PostureThresholds) {
        videoQueue.async { [weak self] in
            self?.baseline = baseline
            self?.thresholds = thresholds
        }
    }

    /// Request camera access (prompts once) and start capturing if granted.
    /// When denied/restricted, emits a single `.unknown` so the UI can show "camera off".
    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.configureAndStart() }
                else { self?.emit(.unknown, nil) }
            }
        default:
            emit(.unknown, nil)   // denied / restricted
        }
    }

    func stop() {
        videoQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureAndStart() {
        videoQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            // Configure inputs/outputs once. On a toggle-off→on cycle the session is reused
            // (stop() only stops it), so re-adding the same input/output would no-op and could
            // leave a half-configured session (RC Med-3). Configure once, just re-start after.
            if !self.sessionConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .vga640x480   // body pose needs little resolution

                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(for: .video)
                if let device, let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.videoQueue)
                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                }

                self.session.commitConfiguration()

                // Camera-busy (FaceTime etc.): emit .unknown while interrupted so the warning
                // machine recovers instead of escalating on a frozen frame. The session resumes
                // on its own when the interruption ends.
                NotificationCenter.default.addObserver(
                    forName: .AVCaptureSessionWasInterrupted, object: self.session, queue: nil
                ) { [weak self] _ in self?.emit(.unknown, nil) }

                self.sessionConfigured = true
            }
            self.session.startRunning()
        }
    }

    private func emit(_ state: PostureState, _ metrics: SlouchMetrics?) {
        // Read the callback on the videoQueue (its isolation domain), then hop to the main
        // actor to invoke it. Works regardless of which thread calls emit (denied-path calls
        // arrive on the auth-callback / main thread).
        videoQueue.async { [weak self] in
            guard let callback = self?._onSample else { return }
            Task { @MainActor in callback(state, metrics) }
        }
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate (videoQueue)

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastProcessed >= minInterval else { return }   // throttle to ~3fps
        lastProcessed = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return   // a single dropped frame is harmless at 3fps
        }

        let joints = Self.extractJoints(from: request, minConfidence: minConfidence)
        let metrics = PostureMetrics.metrics(from: joints)
        let state: PostureState
        if let metrics, let baseline {
            state = PostureMetrics.classify(metrics, baseline: baseline, thresholds: thresholds)
        } else {
            state = .unknown   // joints not visible, or not calibrated yet
        }
        emit(state, metrics)
        // sampleBuffer goes out of scope here - the frame is never retained or stored.
    }

    private static func extractJoints(from request: VNDetectHumanBodyPoseRequest,
                                      minConfidence: Float) -> PostureJoints {
        guard let obs = request.results?.first else { return PostureJoints() }
        func point(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = try? obs.recognizedPoint(name), p.confidence >= minConfidence else { return nil }
            return p.location   // normalized, origin bottom-left
        }
        return PostureJoints(
            nose: point(.nose),
            leftEar: point(.leftEar),
            rightEar: point(.rightEar),
            leftShoulder: point(.leftShoulder),
            rightShoulder: point(.rightShoulder)
        )
    }
}
