//
//  ServiceOperation.swift
//  Copyright © 2016 Kevin Tatroe. All rights reserved.
//

/*
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 * Neither the name Kevin Tatroe nor the names of its contributors may be
 used to endorse or promote products derived from this software without
 specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation


/**
 Handles downloading and processing of a `ServiceRequest`. Callers provide a `ServiceResponseProcessor`
 responsible for processing the response once it's successfully fetched.
*/
public class FetchServiceResponseOperation: GroupOperation {
    // MARK: - Properties

    let downloadOperation: DownloadServiceResponseOperation
    let parseOperation: ProcessServiceResponseOperation


    // MARK: - Initialization

    public init(request: ServiceRequest, session: ServiceSession? = nil, responseProcessor: ServiceResponseProcessor) {
        // If there's no container for us to write to, we're in a completely bogus and irrecoverable state
        // swiftlint:disable force_try
        let cachesFolder = try! NSFileManager.defaultManager().URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        // swiftlint:enable force_try

        var cacheFileName = FetchServiceResponseOperation.randomCacheFileName()

        if let payload = request.payload {
            cacheFileName = "\(payload.hashValue())"
        }

        let cacheFile = cachesFolder.URLByAppendingPathComponent(cacheFileName)

        downloadOperation = DownloadServiceResponseOperation(request: request, session: session, cacheFile: cacheFile)

        parseOperation = ProcessServiceResponseOperation(request: request, responseProcessor: responseProcessor, cacheFile: cacheFile)
        parseOperation.addDependency(downloadOperation)

        super.init(operations: [downloadOperation, parseOperation])

        name = "Fetch Service Request Operation"
    }


    // MARK: - Private

    private static func randomCacheFileName() -> String {
        // TODO: use guid or something similar
        return "cacheFile"
    }
}


/**
 Handles the downloading of an HTTP request via a `NSURLSession` download task and
 storing the downloaded file in a cache file location that continued operations can
 pick up and manipulate.
*/
public class DownloadServiceResponseOperation: GroupOperation {
    // MARK: - Properties

    let request: ServiceRequest

    let cacheFile: NSURL


    // MARK: - Initialization

    public init(request: ServiceRequest, session: ServiceSession? = nil, cacheFile: NSURL) {
        self.request = request
        self.cacheFile = cacheFile

        super.init(operations: [])

        name = "Download Service Request Operation"

        if let urlRequest = request.makeURLRequest(session), url = urlRequest.URL {
            let urlSession = Container.resolve(NSURLSession.self) ?? NSURLSession.sharedSession()

            let task = urlSession.downloadTaskWithURL(url) { url, response, error in
                self.downloadFinished(url, response: response as? NSHTTPURLResponse, error: error)
            }

            let taskOperation = URLSessionTaskOperation(task: task)
            addOperation(taskOperation)
        }
    }


    // MARK: - Private

    private func downloadFinished(url: NSURL?, response: NSHTTPURLResponse?, error: NSError?) {
        if let localURL = url {
            do {
                try NSFileManager.defaultManager().removeItemAtURL(cacheFile)
            } catch { }

            do {
                try NSFileManager.defaultManager().moveItemAtURL(localURL, toURL: cacheFile)
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


/**
 Uses a provided `ServiceResponseProcessor` to process a response downloaded
 into a cache file.
*/
public class ProcessServiceResponseOperation: Operation {
    // MARK: - Properties

    let request: ServiceRequest
    let cacheFile: NSURL

    let responseProcessor: ServiceResponseProcessor


    // MARK: - Initialization

    public init(request: ServiceRequest, responseProcessor: ServiceResponseProcessor, cacheFile: NSURL) {
        self.request = request
        self.cacheFile = cacheFile

        self.responseProcessor = responseProcessor

        super.init()
    }


    // MARK: - Overrides

    override public func execute() {
        guard let stream = NSInputStream(URL: cacheFile) else {
            finish()

            return
        }

        stream.open()

        defer {
            stream.close()
        }

        self.responseProcessor.process(request, input: .stream(stream), completionBlock: { (response: ServiceResponseProcessorParam) -> Void in
            switch response {
            case .stream(_): fallthrough
            case .data(_, _):
                // TODO: should it be an error to have unprocessed data?
                self.finish()
                break

            case .processed(let processed):
                if processed {
                    self.finish()
                    return
                }
            // TODO: should it be an error to have not processed the data?

            case .error(let error):
                self.finishWithError(error)
                return
            }
        })
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
    case stream(NSInputStream)

    /// `NSData` can be used to pipe data from one processor to the next.
    case data(String, NSData)

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
    func process(request: ServiceRequest, input: ServiceResponseProcessorParam, completionBlock: (ServiceResponseProcessorParam) -> Void)
}


/**
 Pipelines multiple `ServiceResponseProcessor` instances to chain processing of input.
*/
/*
public class PipelineServiceResponseProcessor : ServiceResponseProcessor {
    let processors: [ServiceResponseProcessor]


    // MARK: - Initialization

    init(processors: [ServiceResponseProcessor]) {
        self.processors = processors
    }


    // MARK: - Protocols

    // MARK: <ServiceResponseProcessor>

    func process(request: ServiceRequest, input: ServiceResponseProcessorParam, completionBlock: (ServiceResponseProcessorParam) -> Void) {
        var currentInput = input

        // TODO: Wait for the completionBlock of each processor to start the next, oy
        for processor in processors {
            let response = processor.process(request, input: currentInput, completionBlock: (processCompletion: ServiceResponseProcessorParam) in {
                switch response {
                case .stream(_):
                    currentInput = response

                case .data(_, _):
                    currentInput = response

                case .processed(_):
                    return response

                case .error(_):
                    return response
                }
            })
        }

        return .processed(false)
    }
}
*/
