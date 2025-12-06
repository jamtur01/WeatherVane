import Foundation

/// Centralized timer management for coordinating city rotation and UI updates
final class TimerManager {
    private var timer: Timer?
    private var onTick: (() -> Void)?
    
    func start(interval: TimeInterval, tolerance: TimeInterval = 0.1, onTick: @escaping () -> Void) {
        stop()
        
        self.onTick = onTick
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.onTick?()
        }
        
        timer?.tolerance = tolerance
        // Note: scheduledTimer automatically adds the timer to the current run loop,
        // so manual addition is not needed
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        onTick = nil
    }
    
    deinit {
        stop()
    }
}