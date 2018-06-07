//
//  Copyright © 2016 Kevin Tatroe. All rights reserved.
//  See LICENSE.txt for this sample’s licensing information

import Foundation


/**
 Provides a mechanism for updating and remembering the last status for each
 endpoint/payload. Typically used for debugging, a concrete implementation might
 also be used to replay failed attempts when circumstances change (for example,
 converting a task to a background task when switching to the background).
 */
public protocol ServiceStatusHandler: class {
    var statuses: [ServiceEndpointResponseStatus] { get }

    func isIdle(_ identifier: ServiceRequestIdentifier) -> Bool

    func updateStatus(_ identifier: ServiceRequestIdentifier, status: ServiceEndpointStatus)
    func lastStatus(_ identifier: ServiceRequestIdentifier) -> (ServiceEndpointStatus, Date?)
}


/// The current state of a request within this `Service`.
public enum ServiceEndpointState: Int16 {
    case waiting
    case fetching
    case parsing
    case complete
}


/// The last-known status for a given endpoint within this `Service`.
public enum ServiceEndpointStatus: Int16 {
    case unknown
    case failure
    case success
}


/**
 Encapsulates the current state of a fetches against a specific request (`ServiceEndpoint`
 and `ServiceRequestPayload` combination) in an informal state machine.
*/
open class ServiceEndpointResponseStatus {
    // MARK: - Properties

    public let identifier: ServiceRequestIdentifier

    public var updateDate: Date

    public var activityState: ServiceEndpointState = .waiting
    public var status: ServiceEndpointStatus = .unknown

    public var error: NSError?
    public var urlResponse: URLResponse?


    // MARK: - Initialization

    public init(identifier: ServiceRequestIdentifier) {
        self.identifier = identifier

        self.updateDate = Date.distantPast
    }


    // MARK: - Public

    // MARK: Status Updates

    /**
     Indicate that this status has moved from Idle to starting a fetch.
    */
    open func startFetch() {
        changeState(.fetching)
    }

    /**
     Indicate that this status has completed fetching and has begun parsing.

     - parameter response: The `NSURLResponse` that completed, causing the
     status to transition to the parsing state.
     */
    open func startParse(_ response: URLResponse? = nil) {
        urlResponse = response

        changeState(.parsing)
    }

    /**
     Indicate that this status completed with the provided error.

     - parameter completionError: The error that prevented the status from completing
     successfilly.
     */
    open func completeWithError(_ completionError: NSError?) {
        status = .failure
        error = completionError

        changeState(.complete)
    }

    /**
     Indicate that this status has completed successfully.
     */
    open func completeWithSuccess() {
        status = .success

        changeState(.complete)
    }


    // MARK: - Private

    fileprivate func changeState(_ state: ServiceEndpointState) {
        guard activityState != .complete else { return }
        guard state != activityState else { return }

        activityState = state
        updateDate = Date()
    }
}
