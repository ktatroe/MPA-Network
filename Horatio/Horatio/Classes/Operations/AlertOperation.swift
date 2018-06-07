/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 This file shows how to present an alert as part of an operation.
 */

import UIKit

public class AlertOperation: Operation {
    // MARK: Properties

    fileprivate let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
    fileprivate let presentationContext: UIViewController?

    public var title: String? {
        get {
            return alertController.title
        }

        set {
            alertController.title = newValue
            name = newValue
        }
    }

    public var message: String? {
        get {
            return alertController.message
        }

        set {
            alertController.message = newValue
        }
    }

    // MARK: Initialization

    public init(presentationContext: UIViewController? = nil) {
        self.presentationContext = presentationContext
        super.init()

        addCondition(AlertPresentation())

        /*
         This operation modifies the view controller hierarchy.
         Doing this while other such operations are executing can lead to
         inconsistencies in UIKit. So, let's make them mutally exclusive.
         */
        addCondition(MutuallyExclusive<UIViewController>())
    }

    public func addAction(_ title: String, style: UIAlertAction.Style = .default, handler: @escaping (AlertOperation) -> Void = { _ in }) {
        let action = UIAlertAction(title: title, style: style) { [weak self] _ in
            if let strongSelf = self {
                handler(strongSelf)
            }

            self?.finish()
        }

        alertController.addAction(action)
    }

    override public func execute() {
        // it's probably not safe to even walk the view hierarchy from a background thread, so do this all on main
        DispatchQueue.main.async {
            var presentationContext = self.presentationContext
            
            if presentationContext == nil {
                // if no context is provided, use the root VC
                presentationContext = UIApplication.shared.keyWindow?.rootViewController

                // but if something is already presented there, walk down the hierarchy to find the leaf to present on
                while let presentedVC = presentationContext?.presentedViewController {
                    presentationContext = presentedVC
                }
            }

            guard let presenter = presentationContext else {
                // this shouldn't be possible, but just in case
                self.finishWithError(NSError(code: .executionFailed, userInfo:
                    [NSLocalizedDescriptionKey : "Alert operation failed because no presenter was found"]))
                return
            }

            if self.alertController.actions.isEmpty {
                self.addAction("OK")
            }

            if presenter.presentedViewController != nil {
                // presentation will fail if another VC is already presented, so error out the operation
                self.finishWithError(NSError(code: .executionFailed, userInfo:
                    [NSLocalizedDescriptionKey : "Alert operation failed because presenter was already presenting another VC"]))

            } else {
                presenter.present(self.alertController, animated: true, completion: nil)
            }
        }
    }
}
