//
//  Copyright © 2016 Kevin Tatroe. All rights reserved.
//  See LICENSE.txt for this sample’s licensing information

import Foundation


/**
 Handles downloading and processing of a `ServiceRequest`. Callers provide a `ServiceResponseProcessor`
 responsible for processing the response once it's successfully fetched.
*/
open class FetchServiceResponseOperation: GroupOperation {
    // MARK: - Properties

    let downloadOperation: DownloadServiceResponseOperation
    let parseOperation: ProcessServiceResponseOperation


    // MARK: - Initialization

    public init(request: ServiceRequest, session: ServiceSession? = nil, responseProcessor: ServiceResponseProcessor) {
        let cachesFolder = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

        var cacheFileName = FetchServiceResponseOperation.randomCacheFileName()

        if let payload = request.payload {
            cacheFileName = "\(payload.hashValue()).json"
        }

        let cacheFile = cachesFolder.appendingPathComponent(cacheFileName)

        downloadOperation = DownloadServiceResponseOperation(request: request, session: session, cacheFile: cacheFile)

        parseOperation = ProcessServiceResponseOperation(request: request, responseProcessor: responseProcessor, cacheFile: cacheFile)
        parseOperation.addDependency(downloadOperation)
        parseOperation.addCondition(DependencySuccessCondition())

        super.init(operations: [downloadOperation, parseOperation])

        name = "Fetch Service Request Operation"
    }


    // MARK: - Private

    fileprivate static func randomCacheFileName() -> String {
        return UUID().uuidString
    }
}


/**
 Handles the downloading of an HTTP request via a `NSURLSession` download task and
 storing the downloaded file in a cache file location that continued operations can
 pick up and manipulate.
*/
open class DownloadServiceResponseOperation: GroupOperation {
    // MARK: - Properties

    let request: ServiceRequest

    let cacheFile: URL


    // MARK: - Initialization

    public init(request: ServiceRequest, session: ServiceSession? = nil, cacheFile: URL) {
        self.request = request
        self.cacheFile = cacheFile

        super.init(operations: [])

        if let urlRequest = request.makeURLRequest(session) {
            if let url = urlRequest.url {
                name = "Download Service Request Operation \(url)"
                
                let task = URLSession.shared.downloadTask(with: urlRequest, completionHandler: { [weak self] (url, response, error) -> Void in
                    guard let weakSelf = self else { return }
                    guard let response = response as? HTTPURLResponse else { weakSelf.finish(); return }

                    weakSelf.downloadFinished(url, response: response, error: error as NSError?)
                })

                let taskOperation = URLSessionTaskOperation(task: task)
                addOperation(taskOperation)
            }
        }
    }


    // MARK: - Private

    fileprivate func downloadFinished(_ url: URL?, response: HTTPURLResponse?, error: NSError?) {
        if let localURL = url {
            do {
                try FileManager.default.removeItem(at: cacheFile)
            } catch { }

            do {
                try FileManager.default.moveItem(at: localURL, to: cacheFile)
            } catch let error as NSError {
                aggregateError(error)
            }

        } else if let error = error {
            aggregateError(error)
        } else {
            // do nothing and let the operation complete
        }
    }
}

public struct ProcessServiceResponseErrors {
    enum ErrorTypes: Error {
        case notProcessed
    }
    
    static let domain = "ProcessServiceResponseErrors"
    
    struct Codes {
        static let notProcessed = 0
    }
    
    static func errorForType(_ type: ErrorTypes) -> NSError {
        switch type {
        case .notProcessed:
            return NSError(domain: domain, code: Codes.notProcessed, userInfo: nil)
        }
    }
}


/**
 Uses a provided `ServiceResponseProcessor` to process a response downloaded
 into a cache file.
*/
open class ProcessServiceResponseOperation: Operation {
    // MARK: - Properties

    let request: ServiceRequest
    let cacheFile: URL

    let responseProcessor: ServiceResponseProcessor


    // MARK: - Initialization

    public init(request: ServiceRequest, responseProcessor: ServiceResponseProcessor, cacheFile: URL) {
        self.request = request
        self.cacheFile = cacheFile

        self.responseProcessor = responseProcessor

        super.init()
    }


    // MARK: - Overrides

    override open func execute() {
        guard let stream = InputStream(url: cacheFile) else {
            finish()

            return
        }

        stream.open()

        defer {
            stream.close()
            removeCachedFile()
        }

        self.responseProcessor.process(request, input: .stream(stream), completionBlock: { (response: ServiceResponseProcessorParam) -> Void in
            switch response {
            case .stream(_): fallthrough
            case .data(_, _):
                self.finish()
                break

            case .processed(let processed):
                if processed {
                    self.finish()
                    return
                }
                
                self.finishWithError(ProcessServiceResponseErrors.errorForType(.notProcessed))

            case .error(let error):
                self.finishWithError(error)
                return
            }
        })
    }
    
    
    // MARK: - Private
    
    fileprivate func removeCachedFile() {
        do {
            try FileManager.default.removeItem(at: cacheFile)
        } catch { }
    }
}


/**
 Handles moving data from one processor to another. A value may either be terminal or
 non-terminal. Terminal values indicate that processing is complete and the input is
 "consumed". Non-terminal values provide new input that may be further processed (for
 example, in a pipeline of processors).
*/
public enum ServiceResponseProcessorParam {
    /// Initial input is typically a memory-efficient `NSInputStream`.
    case stream(InputStream)

    /// `NSData` can be used to pipe data from one processor to the next.
    case data(String, Data)

    /// The processor was terminal, with an indication of whether the data was completely processed.
    case processed(Bool)

    /// The processor was terminal, and ended with a known error.
    case error(NSError)
}


/**
 Handles input delivered via `ServiceResponseProcessorParam`, processes the data, and returns
 a new `ServiceResponseProcessorParam`, which can then be further processed or, if terminal,
 complete the processing stage of the operation.
*/
public protocol ServiceResponseProcessor: class {
    func process(_ request: ServiceRequest, input: ServiceResponseProcessorParam, completionBlock: @escaping (ServiceResponseProcessorParam) -> Void)
}
