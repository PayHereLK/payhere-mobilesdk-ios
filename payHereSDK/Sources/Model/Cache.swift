//
//  Cache.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 2022-01-24.
//  Copyright © 2022 PayHere. All rights reserved.
//

import Foundation

internal class Cache{
    
    static let shared = Cache()
    
    private let cache = NSCache<NSString, UIImage>()
    var task = URLSessionDataTask()
    var session = URLSession.shared
    
    func image(for url: URL, completionHandler: @escaping (Result<(UIImage?), Error>) -> Void) {
        if let imageInCache = self.cache.object(forKey: url.absoluteString as NSString)  {
            completionHandler(.success(imageInCache))
            return
        }
        
        self.task = self.session.dataTask(with: url) { data, response, error in
            
            if let error = error {
                completionHandler(.failure(error))
                return
            }
            
            let image = UIImage(data: data!)
            
            self.cache.setObject(image ?? UIImage(), forKey: url.absoluteString as NSString)
            completionHandler(.success(image))
        }
        
        self.task.resume()
    }
}

internal extension UIImageView{
    func setImage(from url: URL, placeholder: UIImage? = nil) {
        image = placeholder               // use placeholder (or if `nil`, remove any old image, before initiating asynchronous retrieval
        
        Cache.shared.image(for: url) { [weak self] result in
            switch result {
            case .success(let image):
                DispatchQueue.main.async {
                    self?.image = image
                    self?.contentMode = .scaleAspectFit
                }
            case .failure:
                break
            }
        }
    }
}

