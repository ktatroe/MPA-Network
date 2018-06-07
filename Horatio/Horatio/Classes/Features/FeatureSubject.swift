//
//  Copyright © 2016 Kevin Tatroe. All rights reserved.
//  See LICENSE.txt for this sample’s licensing information

import Foundation


/**
 Abstracts the current user of the app to a unique identifier.
*/
protocol FeatureSubject {
    var identifier: String { get }
}


/**
 `FeatureSubject` that assigns a random identifier for the duration of the current session.
*/
class RandomFeatureSubject: FeatureSubject {
    struct Behaviors {
        static let IdentifierLength = 32
    }
    
    
    let identifier: String
    

    // MARK: - Initialization

    init() {
        self.identifier = RandomFeatureSubject.generateRandomIdentifier(Behaviors.IdentifierLength)
    }
    
    
    // MARK: - Private
    
    fileprivate static func generateRandomIdentifier(_ length: Int) -> String {
        let allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let count = UInt32(allowed.count)

        var identifier = ""
        
        for _ in (0 ..< length) {
            let random = Int(arc4random_uniform(count))
            
            let c = allowed[allowed.index(allowed.startIndex, offsetBy: random)]
            identifier += String(c)
        }
        
        return identifier
    }
}
