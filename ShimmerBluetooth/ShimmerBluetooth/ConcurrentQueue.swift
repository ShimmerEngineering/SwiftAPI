//
//  ConcurrentQueue.swift
//  ShimmerBluetooth
//
//  Created by Joseph Yong on 14/04/2025.
//

import Foundation

public class ConcurrentQueue<T> {
    private var queue: [T] = []
    private let dispatchQueue = DispatchQueue(label: "com.concurrentQueue", attributes: .concurrent)

    public init() { }
    
    public func enqueue(_ element: T) {
        dispatchQueue.async(flags: .barrier) {
            self.queue.append(element)
        }
    }

    public func dequeue() -> T? {
        return dispatchQueue.sync(flags: .barrier) {
            guard !self.queue.isEmpty else { return nil }
            return self.queue.removeFirst()
        }
    }

    func peek() -> T? {
        return dispatchQueue.sync {
            return queue.first
        }
    }

    public var isEmpty: Bool {
        return dispatchQueue.sync {
            return queue.isEmpty
        }
    }
    
    var count: Int {
        return dispatchQueue.sync {
            return queue.count
        }
    }
}
