
import Foundation
import Combine

/// Simple Combine-based debouncer that executes the supplied closure only after
/// the given interval has elapsed since the *last* `call()`.
///
///     debouncer.call { ... } // will run after 0.3 s
///     debouncer.call { ... } // resets the timer
///
final class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue

    init(delay: TimeInterval = 0.3, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    func call(_ block: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: block)
        workItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    deinit {
        workItem?.cancel()
    }
}
