//
//  Copyright © 2016 Kevin Tatroe. All rights reserved.
//  See LICENSE.txt for this sample’s licensing information

import Foundation


/**
 Processes JSON data in some way — transforming, storing, or otherwise manipulating the data.
 */
public protocol JSONProcessor {
    func processJSONData(_ request: ServiceRequest, jsonData: JSONObject, completionBlock: @escaping (_ errors: [NSError]?) -> Void)
    func processJSONDataArray(_ request: ServiceRequest, jsonData: [JSONObject], completionBlock: @escaping (_ errors: [NSError]?) -> Void)
    @available(*, deprecated, message: "Please use processJSONDataArray instead.")
    func processJSONData(_ request: ServiceRequest, jsonData: [JSONObject], completionBlock: @escaping (_ errors: [NSError]?) -> Void)
}


extension JSONProcessor {
    func processJSONData(_ request: ServiceRequest, jsonData: JSONObject, completionBlock: @escaping (_ errors: [NSError]?) -> Void) {
        completionBlock(nil)
    }
    
    func processJSONData(_ request: ServiceRequest, jsonData: [JSONObject], completionBlock: @escaping (_ errors: [NSError]?) -> Void) {
        print("🚫This processJSONData method has been deprecated. Please use processJSONDataArray instead.🚫")
        processJSONDataArray(request, jsonData: jsonData) { (_) in
            completionBlock(nil)
        }
    }
    
    func processJSONDataArray(_ request: ServiceRequest, jsonData: [JSONObject], completionBlock: @escaping (_ errors: [NSError]?) -> Void) {
        completionBlock(nil)
    }
}


/**
 Processes JSON data from a response object and returns an error or a terminal processed case.
 A JSON processor takes a specialized processor for parsing JSON (typically, parsing the JSON
 into objects and storing those in a local store).
 */
open class JSONServiceResponseProcessor: ServiceResponseProcessor {
    // MARK: - Properties

    let jsonProcessor: JSONProcessor


    // MARK: - Initialization


    public init(jsonProcessor: JSONProcessor) {
        self.jsonProcessor = jsonProcessor
    }


    // MARK: - Protocols

    // MARK: <ServiceResponseProcessor>

    open func process(_ request: ServiceRequest, input: ServiceResponseProcessorParam, completionBlock: @escaping (ServiceResponseProcessorParam) -> Void) {
        var jsonData: Any? = nil
        
        do {
            switch input {
            case .stream(let inputStream):
                jsonData = try JSONSerialization.jsonObject(with: inputStream, options: .allowFragments)
                
            case .data(_, let inputData):
                jsonData = try JSONSerialization.jsonObject(with: inputData, options: .allowFragments)
                
            default:
                completionBlock(input)
            }
        } catch let jsonError as NSError {
            print("Error parsing response from \(String(describing: request.url)): \(jsonError)")
            completionBlock(.error(jsonError))
        }

        if let jsonObject = jsonData as? JSONObject {
            processObject(request, jsonObject: jsonObject, completionBlock: completionBlock)
        } else if let jsonArray = jsonData as? [JSONObject] {
            processArray(request, jsonArray: jsonArray, completionBlock: completionBlock)
        } else {
            completionBlock(.processed(false))
        }
    }
    
    
    // MARK: - Private

    fileprivate func processObject(_ request: ServiceRequest, jsonObject: JSONObject, completionBlock: @escaping (ServiceResponseProcessorParam) -> Void) {
        jsonProcessor.processJSONData(request, jsonData: jsonObject) { (errors: [NSError]?) in
            if let error = errors?.first {
                completionBlock(.error(error))
                return
            }
            
            completionBlock(.processed(true))
        }
    }


    fileprivate func processArray(_ request: ServiceRequest, jsonArray: [JSONObject], completionBlock: @escaping (ServiceResponseProcessorParam) -> Void) {
        jsonProcessor.processJSONDataArray(request, jsonData: jsonArray) { (errors: [NSError]?) in
            if let error = errors?.first {
                completionBlock(.error(error))
                return
            }
            
            completionBlock(.processed(true))
        }
    }
}
