//
//  Handle.swift
//  Sealion
//
//  Created by Dima Bart on 2016-10-06.
//  Copyright © 2016 Dima Bart. All rights reserved.
//

import Foundation

public class Handle {
    
    public enum State {
        case running
        case suspended
        case cancelling
        case completed
        
        fileprivate init(state: URLSessionTask.State) {
            switch state {
            case .running:   self = .running
            case .suspended: self = .suspended
            case .canceling: self = .cancelling
            case .completed: self = .completed
            }
        }
    }
    
    public var state: State {
        return State(state: self.task.state)
    }
    
    internal let task:    URLSessionTask
    internal let keyPath: String?
    
    // ----------------------------------
    //  MARK: - Init -
    //
    internal init(task: URLSessionTask, keyPath: String?) {
        self.task    = task
        self.keyPath = keyPath
    }
    
    // ----------------------------------
    //  MARK: - Requests -
    //
    public var originalRequest: URLRequest? {
        return self.task.originalRequest
    }
    
    public var currentRequest: URLRequest? {
        return self.task.currentRequest
    }
    
    // ----------------------------------
    //  MARK: - Response -
    //
    public var response: URLResponse? {
        return self.task.response
    }
    
    // ----------------------------------
    //  MARK: - Actions -
    //
    public func cancel() {
        self.task.cancel()
    }
    
    public func suspend() {
        self.task.suspend()
    }
    
    public func resume() {
        self.task.resume()
    }
}