//
//  Net.swift
//  ChildrenProgramClass
//
//  Created by jiangyouhua on 2021/10/22.
//


import Foundation
import SystemConfiguration

open class JYHNet: NSObject {
    public static var shared = JYHNet()
    private var timeout: TimeInterval = 60
    private var observation: NSKeyValueObservation?

    deinit {
        observation?.invalidate()
    }

    public typealias Progress = (_ progress: Double) -> Void

    public enum NetError: Error {
        case notNet // 没有联网。
        case invalidURL(String) // 无效URL。
        case requestError(Error) // 请求返回错误。
        case invalidResponse(URLResponse) // 返回的URLResponse无法转为HTTPResponse。
        case responseError(Int) // 非200返回。
        case emptyData // 空数据。
        case parsingFailed(Error) // 解析失败。
    }
    
    private func dataWithGet(address: String, dic: [String: Any]?) ->URLRequest? {
        guard let url = URL(string: address) else {
            return nil
        }
        
        guard let dic =  dic else {
            return URLRequest(url: url, timeoutInterval: timeout)
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        var items: [URLQueryItem] = [URLQueryItem]()
        for (key, value) in dic {
            items.append(URLQueryItem(name: key, value: "\(value)"))
        }
        components?.queryItems = items
        return URLRequest(url: components?.url ?? url, timeoutInterval: timeout)
    }
    
    private func dataWithPost(address: String, dic:[String: Any]?) ->URLRequest? {
        guard let url = URL(string: address) else {
            return nil
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        guard let dic =  dic else {
            return request
        }
        guard let httpBody = try? JSONSerialization.data(withJSONObject: dic, options: .prettyPrinted) else {
            return nil
        }
        request.httpBody = httpBody
        return request
    }
    
    // 判断当前网络。
    public func haveNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }

        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        if flags.isEmpty {
            return false
        }

        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)

        return (isReachable && !needsConnection)
    }
    
    public func setTimeout(_ timeout: TimeInterval) -> JYHNet {
        self.timeout = timeout
        return self
    }
    
    public func get<T: Codable>(_ address: String, dic:[String: Any]?, back: @escaping (Result<T, NetError>)->Void) {
        if !haveNetwork() {
            return back(.failure(.notNet))
        }
        guard var re = dataWithGet(address: address, dic: dic) else {
            return back(.failure(.invalidURL(address)))
        }
        re.httpMethod = "GET"
        return request(re, back: back, progress: nil)
    }

    public func post<T: Codable>(_ address: String, dic:[String: Any]?,  back: @escaping (Result<T, NetError>)->Void){
        if !haveNetwork() {
            return back(.failure(.notNet))
        }
        guard var re = dataWithGet(address: address, dic: dic) else {
            return back(.failure(.invalidURL(address)))
        }
        re.httpMethod = "POST"
        return request(re, back: back, progress: nil)
    }
    
    // 请求数据。
    private func request<T: Codable>(_ re: URLRequest, back: @escaping (Result<T, NetError>) -> Void, progress: Progress?) {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: re) { data, response, error in
            // 请求错误。
            if error != nil {
                return back(.failure(.requestError(error!)))
            }
            // 请求返回错误。
            guard let httpResponse = response as? HTTPURLResponse else {
                return back(.failure(.invalidResponse(response!)))
            }
            // 请求成功。返回HTTP码，只处理错误码。
            if !(200 ... 299).contains(httpResponse.statusCode) {
                return back(.failure(.responseError(httpResponse.statusCode)))
            }
            // 请求成功，数据为空。
            if data == nil {
                return back(.failure(.emptyData))
            }
            
            let decoder = JSONDecoder()
            do {
                let result = try decoder.decode(T.self, from: data!)
                return back(.success(result))
            } catch {
                return back(.failure(.parsingFailed(error)))
            }
            
        }
        task.resume()
    }
    
    public func download(_ address: String, back: @escaping (Result<URL, NetError>)->Void, progress: Progress?){
        if !haveNetwork() {
            return back(.failure(.notNet))
        }
        guard var re = dataWithGet(address: address, dic: nil) else {
            return back(.failure(.invalidURL(address)))
        }
        re.httpMethod = "GET"
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.downloadTask(with: re) {url, response, error in
            // 请求错误。
            if error != nil {
                return back(.failure(.requestError(error!)))
            }
            // 请求返回错误。
            guard let httpResponse = response as? HTTPURLResponse else {
                return back(.failure(.invalidResponse(response!)))
            }
            // 请求成功。返回HTTP码，只处理错误码。
            if !(200 ... 299).contains(httpResponse.statusCode) {
                return back(.failure(.responseError(httpResponse.statusCode)))
            }
            // 请求成功，数据为空。
            if url == nil {
                return back(.failure(.emptyData))
            }
            return back(.success(url!))
        }

        // 下面是针对加载进度的处理。不限定的话会引起在iPad使用时的崩溃。
        if progress != nil {
            observation = task.progress.observe(\.fractionCompleted) { pro, _ in
                DispatchQueue.main.async {
                    progress?(pro.fractionCompleted)
                }
            }
        }
        
        task.resume()
    }
}
