//
//  Copyright © 2016 Kevin Tatroe. All rights reserved.
//  See LICENSE.txt for this sample’s licensing information

import Foundation


/**
 Transforms a `NSURLRequest` into handling a specific request type. For example, a
 concrete implementation might generate a "Create Post" request.
 */
public protocol ServiceRequestConfigurator: class {
    func configureURL(_ serviceRequest: ServiceRequest) -> URL?
    func configureURLRequest(_ serviceRequest: ServiceRequest, urlRequest: NSMutableURLRequest) -> NSMutableURLRequest

    func endpointPathTransformers(_ serviceRequest: ServiceRequest) -> [ServiceEndpointPathTransformer]
    func urlRequestDecorators(_ serviceRequest: ServiceRequest) -> [ServiceRequestDecorator]
}


/// Provides base functionality for implementations of `ServiceRequestConfigurator`.
public extension ServiceRequestConfigurator {
    public func configureURL(_ serviceRequest: ServiceRequest) -> URL? {
        switch serviceRequest.endpoint.urlContainer {
            case .components(var components):
                for transformer in endpointPathTransformers(serviceRequest) {
                    components = transformer.transformedPath(components)
                }
                
                components = rectifyEmbeddedQuery(components: components)

                return components.url

            case .absolutePath(let urlString):
                var basePath = urlString

                for transformer in endpointPathTransformers(serviceRequest) {
                    basePath = transformer.transformedPath(basePath)
                }

                return URL(string: basePath)
        }
    }


    public func configureURLRequest(_ serviceRequest: ServiceRequest, urlRequest: NSMutableURLRequest) -> NSMutableURLRequest {
        for decorator in urlRequestDecorators(serviceRequest) {
            decorator.compose(urlRequest)
        }

        return urlRequest
    }

    /**
     Handles the case where there are query parameters embedded in the path. Properly
     pulls them out and merges them into the query.
     */
    private func rectifyEmbeddedQuery(components: URLComponents) -> URLComponents {
        let path = components.path

        guard let range = path.range(of: "?") else { return components }

        var newComponents = components
        newComponents.path = String(path[path.startIndex ..< range.lowerBound])
        let queryString = String(path[range.upperBound ..< path.endIndex])

        var queryItems = [URLQueryItem]()

        // grab any existing, non-embedded query items
        if let existingQuery = newComponents.queryItems {
            queryItems += existingQuery
        }

        // let it parse the embedded query for us
        newComponents.query = queryString

        // grab any newly parsed query items
        if let newQuery = newComponents.queryItems {
            queryItems += newQuery
        }

        // set the complete set of query items
        newComponents.queryItems = queryItems

        return newComponents
    }
}


/**
 Handles a generic key-value store of entries dropped into the URL as GET or POST
 parameters, with no endpoint path transformations.
 */
open class DictionaryServiceRequestConfigurator: ServiceRequestConfigurator {
    // MARK: - Properties

    let parameters: [String : String]


    // MARK: - Initialization

    public init(parameters: [String : String]) {
        self.parameters = parameters
    }


    // MARK: - Protocols

    // MARK: <ServiceRequestConfigurator>

    open func endpointPathTransformers(_ serviceRequest: ServiceRequest) -> [ServiceEndpointPathTransformer] {
        return [ServiceEndpointPathTransformer]()
    }

    open func urlRequestDecorators(_ serviceRequest: ServiceRequest) -> [ServiceRequestDecorator] {
        let decorator = HTTPParametersBodyServiceRequestDecorator(type: serviceRequest.endpoint.type, parameters: parameters)

        return [decorator]
    }
}


