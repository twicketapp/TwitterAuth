//
//  ReverseOAuth.swift
//  TwitterReverseOAuth
//
//  Created by Pol Quintana on 30/01/16.
//  Copyright © 2016 Pol Quintana. All rights reserved.
//

import Foundation
import Accounts
import UIKit

public typealias TwitterAuthCompletion = (result: TwitterAuthResult?, error: TwitterAuthError?) -> ()
public typealias TwitterAuthErrorCompletion = (error: TwitterAuthError?) -> ()

public enum TwitterAuthError: ErrorType {
    case ErrorGettingHeader
    case ErrorGettingTokens
    case BadURLRequest
    case NoAccessToAccounts
    case NoAvailableAccounts
    case Unknown
}

public protocol TwitterAuthWebLoginDelegate: class {
    func didSuccedRetrivingToken(result: TwitterAuthResult)
    func didFailRetrievingToken(error: TwitterAuthError)
}

public class TwitterAuth {
    
    public static let sharedInstance = TwitterAuth()
    public weak var webLoginDelegate: TwitterAuthWebLoginDelegate?
    
    private var apiManager: APIManager = APIManager()
    private let webManager: TwicketWebManager = TwicketWebManager()
    
    public func configure(withConsumerKey consumerKey: String, consumerSecret: String, callbackURL: String) {
        self.apiManager.consumerKey = consumerKey
        self.apiManager.consumerSecret = consumerSecret
        self.webManager.consumerSecret = consumerKey
        self.webManager.consumerKey = consumerSecret
        self.webManager.callbackStringURL = callbackURL
    }
    
    public func executeReverseOAuth(forAccount account: ACAccount, completion: TwitterAuthCompletion) {
        apiManager.executeReverseAuth(forAccount: account) { result, error in
            Threading.executeOnMainThread { completion(result: result, error: error) }
        }
    }
    
    public func executeReverseOAuthWithAvailableAccounts(onViewController vc: UIViewController,
        completion: TwitterAuthCompletion) {
            getTwitterAccounts { (accounts, error) in
                guard let accounts = accounts else {
                    return Threading.executeOnMainThread { completion(result: nil, error: error) }
                }
                self.showAccountsAlertView(onViewController: vc, withAccounts: accounts) { selectedAccount in
                    self.executeReverseOAuth(forAccount: selectedAccount, completion: completion)
                }
            }
    }
    
    public func presentWebLogin(fromViewController viewController: UIViewController) {
        Threading.executeOnBackgroundThread {
            self.apiManager.obtainRequestToken(self.webManager.callbackStringURL) { token, error in
                Threading.executeOnMainThread {
                    guard let token = token else {
                        self.notifyWebLoginError(error ?? .Unknown)
                        return
                    }
                    self.webManager.openLogin(onViewController: viewController, token: token)
                }
            }
        }
    }
    
    public func processAuthCallback(callback: NSURL) {
        Threading.executeOnBackgroundThread {
            self.webManager.processAuthCallback(callback) { result, error in
                Threading.executeOnMainThread {
                    guard let result = result else {
                        self.notifyWebLoginError(error ?? .Unknown)
                        return
                    }
                    self.notifyWebLoginSuccess(result)
                }
            }
        }
    }
    
    
    //MARK: Private methods
    
    private func notifyWebLoginSuccess(result: TwitterAuthResult) {
        self.webLoginDelegate?.didSuccedRetrivingToken(result)
        hideSafariViewController()
    }
    
    private func notifyWebLoginError(error: TwitterAuthError) {
        self.webLoginDelegate?.didFailRetrievingToken(error ?? .Unknown)
        hideSafariViewController()
    }
    
    private func hideSafariViewController() {
        print(self.webLoginDelegate)
    }
    
    private func getTwitterAccounts(completion: (accounts: [ACAccount]?, error: TwitterAuthError?) -> ()) {
        let accountStore = ACAccountStore()
        let type = accountStore.accountTypeWithAccountTypeIdentifier(ACAccountTypeIdentifierTwitter)
        accountStore.requestAccessToAccountsWithType(type, options: nil) { succeed, error in
            guard succeed else {
                return completion(accounts: nil, error: .NoAccessToAccounts)
            }
            guard let accounts = accountStore.accountsWithAccountType(type) as? [ACAccount]
                where !accounts.isEmpty else {
                    return completion(accounts: nil, error: .NoAvailableAccounts)
            }
            completion(accounts: accounts, error: nil)
        }
    }
    
    private func showAccountsAlertView(onViewController vc: UIViewController,
        withAccounts accounts: [ACAccount],
        selectedAccountBlock: (selectedAccount: ACAccount) -> ()) {
            
            let alert = UIAlertController(title: "Available Accounts",
                message: "(Twitter)",
                preferredStyle: .ActionSheet)
            accounts.forEach { account in
                let action = UIAlertAction(title: account.username,
                    style: .Default) { (action) in
                        selectedAccountBlock(selectedAccount: account)
                }
                alert.addAction(action)
            }
            
            let cancel = UIAlertAction(title: "Cancel", style: .Cancel) { _ in
                alert.dismissViewControllerAnimated(true, completion: nil)
            }
            alert.addAction(cancel)
            
            Threading.executeOnMainThread {
                vc.presentViewController(alert, animated: true, completion: nil)
            }
    }
}

