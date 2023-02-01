//
//  BookList.swift
//  URLSession+Rx
//
//  Created by mobile on 2023/02/01.
//

import Foundation

struct BookCount {
    static var value:Int?
}


// MARK: - BookList
struct BookList: Codable {
    let list: [List]
    let totalCount, code: Int
    let message: String?
}

// MARK: - List
struct List: Codable {
    let id: Int
    let title, description: String
    let yes24Link: String
    let publicationDate: String
}

