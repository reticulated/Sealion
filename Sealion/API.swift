//
//  API.swift
//  Sealion
//
//  Created by Dima Bart on 2016-10-02.
//  Copyright © 2016 Dima Bart. All rights reserved.
//

import Foundation

public class API {
    
    public enum Version: String {
        case v2 = "https://api.digitalocean.com/v2/"
    }
    
    public let version:  Version
    public let token:    String
    
    private let apiRoot: URL
    private let session: URLSession
    
    // ----------------------------------
    //  MARK: - Init -
    //
    public convenience init(version: Version, token: String) {
        self.init(version: version, token: token, session: nil)
    }
    
    internal init(version: Version, token: String, session: URLSession? = nil) {
        self.version = version
        self.token   = token
        self.apiRoot = URL(string: self.version.rawValue)!
        
        if let session = session {
            self.session = session
        } else {
            self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: OperationQueue())
        }
    }
    
    // ----------------------------------
    //  MARK: - URL Generation -
    //
    internal func urlTo(endpoint: Endpoint, page: Page? = nil, parameters: ParameterConvertible? = nil) -> URL {
        let url        = URL(string: endpoint.path, relativeTo: self.apiRoot)!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        
        var p: ParameterConvertible = [:]
        p = p.combineWith(convertible: page)
        p = p.combineWith(convertible: parameters)
        
        let finalParameters = p.parameters
        if !finalParameters.isEmpty {
            var items = [URLQueryItem]()
            for (name, value) in finalParameters {
                items.append(URLQueryItem(name: name, value: value))
            }
            components.queryItems = items
        }
        
        return components.url!
    }
    
    // ----------------------------------
    //  MARK: - Request Generation -
    //
    internal func requestTo(endpoint: Endpoint, method: Method, page: Page? = nil, parameters: ParameterConvertible? = nil, payload: JsonConvertible? = nil) -> URLRequest {
        
        var request        = URLRequest(url: self.urlTo(endpoint: endpoint, page: page, parameters: parameters))
        request.httpMethod = method.rawValue
        
        if let payload = payload {
            request.httpBody = try! JSONSerialization.data(withJSONObject: payload.json, options: [])
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    // ----------------------------------
    //  MARK: - Request Execution -
    //
    internal func taskWith<T: JsonCreatable>(request: URLRequest, keyPath: String? = nil, completion: @escaping (Result<T>) -> Void) -> Handle<T> {
        
        return self.taskWith(request: request, keyPath: keyPath) { result, respose in
            switch result {
            case .success(let json):
                
                var object: T?
                if let json = json {
                    object = T(json: json as! JSON)
                }
                completion(.success(object))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    internal func taskWith<T: JsonCreatable>(request: URLRequest, keyPath: String? = nil, completion: @escaping (Result<[T]>) -> Void) -> Handle<[T]> {
        
        return self.taskWith(request: request, keyPath: keyPath) { result, response in
            switch result {
            case .success(let json):
                
                var collection: [T]?
                if let json = json as? [JSON] {
                    collection = json.map {
                        T(json: $0)
                    }
                }
                completion(.success(collection))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    internal func taskWith<T>(request: URLRequest, keyPath: String? = nil, completion: @escaping (Result<Any>, HTTPURLResponse) -> Void) -> Handle<T> {
        let task = self.session.dataTask(with: request) { (data, response, error) in
            
            /* ---------------------------------
             ** We always expect to get back an
             ** HTTPURLResponse since we can be
             ** relying on the statusCode of the
             ** response.
             */
            let httpResponse = response as! HTTPURLResponse
            
            var parsedError: RequestError?
            var parsedJson:  Any?
            
            /* -----------------------------
             ** Parse the body JSON if it is
             ** not nil.
             */
            if let data = data,
                var json = try? JSONSerialization.jsonObject(with: data, options: []) {
                
                /* ---------------------------------
                 ** If a keyPath was provided, and
                 ** the response was success, we'll
                 ** unwrap the json object. Otherwise
                 ** we assume the root is the error.
                 */
                if httpResponse.successful {
                    
                    if let keyPath = keyPath {
                        let components = keyPath.components(separatedBy: ".")
                        for component in components {
                            json = (json as! JSON)[component]
                        }
                    }
                    parsedJson = json
                    
                } else {
                    var errorJSON     = json as! JSON
                    errorJSON["code"] = httpResponse.statusCode
                    parsedError       = RequestError(json: errorJSON)
                }
            }
            
            /* ------------------------------------
             ** Use the response codes to determine
             ** whether the request succeeded or not.
             */
            if httpResponse.successful {
                completion(.success(parsedJson), httpResponse)
            } else {
                
                if let error = error, parsedError == nil {
                    parsedError = RequestError(code: httpResponse.statusCode, id: "", name: "network_error", description: error.localizedDescription)
                }
                completion(.failure(parsedError), httpResponse)
            }
        }
        
        return Handle(task: task, keyPath: keyPath)
    }
}

// ----------------------------------
//  MARK: - HTTPURLResponse -
//
extension HTTPURLResponse {
    var successful: Bool {
        return (self.statusCode / 100) == 2
    }
}

