//
//  Copyright © 2016 Kevin Tatroe. All rights reserved.
//  See LICENSE.txt for this sample’s licensing information

import Foundation


/**
 Implementations of `EndpointPathTransformer` transform a URL's base path. Concrete
 implementations might substitute values or replace the path entirely based on provided
 values.
 */
public protocol ServiceEndpointPathTransformer: class {
    func transformedPath(_ path: String) -> String
}

extension ServiceEndpointPathTransformer {
    func transformedPath(_ components: URLComponents) -> URLComponents {
        let path = components.path
        guard var newComponents = (components as NSURLComponents).copy() as? URLComponents else { return components }
        
        newComponents.path = transformedPath(path)
        
        return newComponents
    }
}


/**
 A `EndpointPathTransformer` defined by substitutions; for example,
 "http://example.com/game_[GAMEID].json".
 */
open class SubstitutionsServiceEndpointPathTransformer: ServiceEndpointPathTransformer {
    // MARK: - Properties

    let substitutions: [String : String]
    let format: String


    // MARK: - Initialization

    public init(substitutions: [String : String], format: String = "{%@}") {
        self.substitutions = substitutions
        self.format = format
    }


    // MARK: - Protocols

    // MARK: <ServiceEndpointPathTransformer>

    open func transformedPath(_ path: String) -> String {
        var endpointPath = path

        for key in substitutions.keys {
            let identifier = String.init(format: format, key)

            if let value = substitutions[key] {
                endpointPath = endpointPath.replacingOccurrences(of: identifier, with: value)
            }
        }

        return endpointPath
    }
}

/**
 A `EndpointPathTransformer` subclass defined by a RESTful locator chain; for example,
 "http://example.com/:year/game/:id".
 */
open class LocatorChainServiceEndpointPathTransformer: ServiceEndpointPathTransformer {
    // MARK: - Properties

    let locator: [String]


    // MARK: - Initialization

    public init(locator: [String]) {
        self.locator = locator
    }


    // MARK: - Protocols

    // MARK: <ServiceEndpointPathTransformer>

    open func transformedPath(_ path: String) -> String {
        var endpointPath = path

        var transformedComponents: [String] = []
        var index = 0

        for pathPart in endpointPath.components(separatedBy: "/") {
            if !pathPart.isEmpty && pathPart[pathPart.startIndex] == ":" {
                if index < locator.count {
                    // replace the next ":(foo)" with the first locator remaining
                    transformedComponents.append(locator[index])

                    index += 1
                } else {
                    // too few items in the locator chain
                    return path
                }
            } else {
                transformedComponents.append(pathPart)
            }
        }

        if index < locator.count {
            // too many values in the locator chain
            return path
        }

        endpointPath = transformedComponents.joined(separator: "/")

        return endpointPath
    }
}
