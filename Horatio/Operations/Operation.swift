/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
This file contains the foundational subclass of NSOperation.
*/

import Foundation

/**
    The subclass of `NSOperation` from which all other operations should be derived.
    This class adds both Conditions and Observers, which allow the operation to define
    extended readiness requirements, as well as notify many interested parties
    about interesting operation state changes
*/
open class Operation: Foundation.Operation {

    // use the KVO mechanism to indicate that changes to "state" affect other properties as well
    class func keyPathsForValuesAffectingIsReady() -> Set<NSObject> {
        return ["state" as NSObject]
    }

    class func keyPathsForValuesAffectingIsExecuting() -> Set<NSObject> {
        return ["state" as NSObject]
    }

    class func keyPathsForValuesAffectingIsFinished() -> Set<NSObject> {
        return ["state" as NSObject]
    }

    class func keyPathsForValuesAffectingIsCancelled() -> Set<NSObject> {
        return ["state" as NSObject]
    }

    // MARK: State Management

    fileprivate enum State: Int, Comparable {
        /// The initial state of an `Operation`.
        case initialized

        /// The `Operation` is ready to begin evaluating conditions.
        case pending

        /// The `Operation` is evaluating conditions.
        case evaluatingConditions

        /**
            The `Operation`'s conditions have all been satisfied, and it is ready
            to execute.
        */
        case ready

        /// The `Operation` is executing.
        case executing

        /**
            Execution of the `Operation` has finished, but it has not yet notified
            the queue of this.
        */
        case finishing

        /// The `Operation` has finished executing.
        case finished

        /// The `Operation` has been cancelled.
        case cancelled
    }

    /**
        Indicates that the Operation can now begin to evaluate readiness conditions,
        if appropriate.
    */
    func willEnqueue() {
        state = .pending
    }

    /// Private storage for the `state` property that will be KVO observed.
    fileprivate var _state = State.initialized

    fileprivate var state: State {
        get {
            return _state
        }

        set(newState) {
            // Manually fire the KVO notifications for state change, since this is "private".

            willChangeValue(forKey: "state")

            switch (_state, newState) {
                case (.cancelled, _):
                    break // cannot leave the cancelled state
                case (.finished, _):
                    break // cannot leave the finished state
                default:
                    assert(_state != newState, "Performing invalid cyclic state transition.")
                    _state = newState
            }

            didChangeValue(forKey: "state")
        }
    }

    // Here is where we extend our definition of "readiness".
    override open var isReady: Bool {
        switch state {
            case .pending:
                if super.isReady {
                    evaluateConditions()
                }

                return false

            case .ready:
                return super.isReady

            default:
                return false
        }
    }

    open var userInitiated: Bool {
        get {
            return qualityOfService == .userInitiated
        }

        set {
            assert(state < .executing, "Cannot modify userInitiated after execution has begun.")

            qualityOfService = newValue ? .userInitiated : .default
        }
    }
    
    /// Did the operation finish with an error
    fileprivate(set) open var failed = false

    override open var isExecuting: Bool {
        return state == .executing
    }

    override open var isFinished: Bool {
        return state == .finished
    }

    override open var isCancelled: Bool {
        return state == .cancelled
    }

    fileprivate func evaluateConditions() {
        assert(state == .pending, "evaluateConditions() was called out-of-order")

        state = .evaluatingConditions

        OperationConditionEvaluator.evaluate(conditions, operation: self) { failures in
            if failures.isEmpty {
                // If there were no errors, we may proceed.
                self.state = .ready
            } else {
                self.state = .cancelled
                self.finish(failures)
            }
        }
    }

    // MARK: Observers and Conditions

    fileprivate(set) var conditions = [OperationCondition]()

    open func addCondition(_ condition: OperationCondition) {
        assert(state < .evaluatingConditions, "Cannot modify conditions after execution has begun.")

        conditions.append(condition)
    }

    fileprivate(set) var observers = [OperationObserver]()

    open func addObserver(_ observer: OperationObserver) {
        assert(state < .executing, "Cannot modify observers after execution has begun.")

        observers.append(observer)
    }

    override open func addDependency(_ operation: Foundation.Operation) {
        assert(state <= .executing, "Dependencies cannot be modified after execution has begun.")

        super.addDependency(operation)
    }

    // MARK: Execution and Cancellation

    override final public func start() {
        if let name = self.name {
            print("\(name) started")
        }

        assert(state == .ready, "This operation must be performed on an operation queue.")

        state = .executing

        for observer in observers {
            observer.operationDidStart(self)
        }

        execute()
    }

    /**
        `execute()` is the entry point of execution for all `Operation` subclasses.
        If you subclass `Operation` and wish to customize its execution, you would
        do so by overriding the `execute()` method.

        At some point, your `Operation` subclass must call one of the "finish"
        methods defined below; this is how you indicate that your operation has
        finished its execution, and that operations dependent on yours can re-evaluate
        their readiness state.
    */
    open func execute() {
        print("\(type(of: self)) must override `execute()`.")

        finish()
    }

    fileprivate var _internalErrors = [NSError]()
    override open func cancel() {
        cancelWithError()
    }

    open func cancelWithError(_ error: NSError? = nil) {
        if let error = error {
            _internalErrors.append(error)
        }

        state = .cancelled
    }

    final func produceOperation(_ operation: Foundation.Operation) {
        for observer in observers {
            observer.operation(self, didProduceOperation: operation)
        }
    }

    // MARK: Finishing

    /**
        Most operations may finish with a single error, if they have one at all.
        This is a convenience method to simplify calling the actual `finish()`
        method. This is also useful if you wish to finish with an error provided
        by the system frameworks. As an example, see `DownloadEarthquakesOperation`
        for how an error from an `NSURLSession` is passed along via the
        `finishWithError()` method.
    */
    final public func finishWithError(_ error: NSError?) {
        if let error = error {
            finish([error])
        } else {
            finish()
        }
    }

    /**
        A private property to ensure we only notify the observers once that the
        operation has finished.
    */
    fileprivate var hasFinishedAlready = false
    final public func finish(_ errors: [NSError] = []) {
        if !hasFinishedAlready {
            hasFinishedAlready = true
            state = .finishing

            let combinedErrors = _internalErrors + errors
            failed = !combinedErrors.isEmpty
            
            if let name = name {
                if failed {
                    print("\(name) failed due to errors")
                } else {
                    print("\(name) finished")
                }
            }
            
            finished(combinedErrors)

            for observer in observers {
                observer.operationDidFinish(self, errors: combinedErrors)
            }

            state = .finished
        }
    }

    /**
        Subclasses may override `finished(_:)` if they wish to react to the operation
        finishing with errors. For example, the `LoadModelOperation` implements
        this method to potentially inform the user about an error when trying to
        bring up the Core Data stack.
    */
    open func finished(_ errors: [NSError]) {
        // No op.
    }

    override open func waitUntilFinished() {
        /*
            Waiting on operations is almost NEVER the right thing to do. It is
            usually superior to use proper locking constructs, such as `dispatch_semaphore_t`
            or `dispatch_group_notify`, or even `NSLocking` objects. Many developers
            use waiting when they should instead be chaining discrete operations
            together using dependencies.

            To reinforce this idea, invoking `waitUntilFinished()` will crash your
            app, as incentive for you to find a more appropriate way to express
            the behavior you're wishing to create.
        */
        fatalError("Waiting on operations is an anti-pattern. Remove this ONLY if you're absolutely sure there is No Other Way™.")
    }

}

// Simple operator functions to simplify the assertions used above.
private func < (lhs: Operation.State, rhs: Operation.State) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

private func == (lhs: Operation.State, rhs: Operation.State) -> Bool {
    return lhs.rawValue == rhs.rawValue
}
