//
//  Copyright © 2016 Kevin Tatroe. All rights reserved.
//  See LICENSE.txt for this sample’s licensing information

import Foundation


/// The HTTP request type of an endpoint.
public enum ServiceEndpointType : String {
    /// Fetch data for an HTTP resource (i.e., GET)
    case get = "GET"

    /// Update data for an HTTP resource (i.e., POST)
    case post = "POST"

    /// Create a new HTTP resource (i.e., PUT)
    case put = "PUT"

    /// Delete an existing HTTP resource (i.e., DELETE)
    case delete = "DELETE"

    /// Fetch headers for an HTTP service (i.e., HEADER)
    case header = "HEADER"
}


/**
 Stores and provides named `ServiceEndpoint` instances. Each application will
 generally have a single `ServiceEndpointProvider` active at any given moment,
 but can switch between them as necessary (for example, when switching environments).
 */
public protocol ServiceEndpointProvider: class {
    func endpoint(_ identifier: String) -> ServiceEndpoint?
}


/**
 Stores information about a `ServiceEndpoint` URL.
*/
public enum ServiceEndpointURLContainer {
    // URL is contained in an `NSURLComponents` object
    case components(URLComponents)

    // URL is contained in a self-contained complete URL
    case absolutePath(String)
}

/**
 Abstracts details of an API endpoint and turning endpoint information into `NSURL`
 instances (which can then be turned into `NSURLRequest` instances via the
 appropriate `Service`).
 */
open class ServiceEndpoint {
    // MARK: - Properties

    public let identifier: String

    public var urlContainer: ServiceEndpointURLContainer

    public var type: ServiceEndpointType = .get

    public var isAuthRequired: Bool = false
    public var isIdempotent: Bool = true


    // MARK: - Initialization

    public init(identifier: String) {
        self.identifier = identifier
        self.urlContainer = .absolutePath("")
    }


    public convenience init(identifier: String, scheme: String, hostName: String, basePath: String, path: String) {
        self.init(identifier: identifier)

        var components = URLComponents()
        components.scheme = scheme
        components.host = hostName
        components.path = "\(basePath)/\(path)"

        self.urlContainer = .components(components)
    }


    public convenience init(identifier: String, path: String) {
        self.init(identifier: identifier)

        self.urlContainer = .absolutePath(path)
    }


    // MARK: - Public

    // MARK: URLs

    /**
     Return an `NSURL` created by putting the scheme, host, and base path together. Most
     often, this would be modified by one or more `ServiceEndpointPathTransformer` instances
     attached to a `ServiceRequest`.
     */
    open func url() -> URL? {
        switch urlContainer {
        case .components(let components):
            return components.url
        case .absolutePath(let urlString):
            return URL(string: urlString)
        }
    }
}
