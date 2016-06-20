//
//  DependencySuccessCondition.swift
//  NBA
//
//  Created by Nate Petersen on 6/10/16.
//  Copyright © 2016 NBA Digital. All rights reserved.
//

import Foundation

/// A condition that requires all dependencies to have finished without reporting an error.
struct DependencySuccessCondition: OperationCondition {

    static let name = "DependencySuccess"
    static let isMutuallyExclusive = false

    init() { }

    func dependencyForOperation(operation: Operation) -> NSOperation? {
        return nil
    }

    func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
        for dependency in operation.dependencies {
            if let fallibleDependency = dependency as? Operation where fallibleDependency.failed {
                let error = NSError(code: .ConditionFailed, userInfo: [
                    OperationConditionKey: self.dynamicType.name
                    ])

                completion(.Failed(error))
                return
            }
        }

        completion(.Satisfied)
    }
}
