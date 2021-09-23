//
//  ViewController.swift
//  JYHNet
//
//  Created by 3424079 on 09/22/2021.
//  Copyright (c) 2021 3424079. All rights reserved.
//

import UIKit
import JYHNet

class ViewController: UIViewController, UITableViewDataSource {
    private var data: [Category]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tableView = UITableView(frame: self.view.bounds)
        tableView.dataSource = self
        view.addSubview(tableView)
        
        let address = "https://muutr.com/back"
        JYHNet.shared.get(address, dic: ["table":"category", "handle": "get"]) { [weak self] (result: Result<Back<Category>, JYHNet.NetError>) in
            switch result {
            case .success(let success):
                if success.status != 0 {
                    print(success.data)
                } else {
                    self?.data = success.data
                    DispatchQueue.main.async {
                        tableView.reloadData()
                    }
                }
            case .failure(let failure):
                print(failure)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        guard let data = self.data?[indexPath.row] else {
            return cell
        }
        cell.textLabel?.text = data.name
        cell.detailTextLabel?.text = data.info
        return cell
    }
    
}

struct Category: Codable {
    var id: String?
    var name: String?
    var info: String?
    var rank: String?
    var sequence: String?
    var progress: String?
    var collect: String?
    var understand: String?
    var status: String?
}

struct Back<T: Codable>: Codable {
    var status: Int
    var data: [T]
    
    enum CodingKeys: String, CodingKey {
        case status = "Status"
        case data = "Data"
    }
}

