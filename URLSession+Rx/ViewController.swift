//
//  ViewController.swift
//  URLSession+Rx
//
//  Created by mobile on 2023/02/01.
//

import UIKit
import RxSwift
import RxCocoa

public class SimpleError: Error {
    public init() { }
}

class ViewController: UITableViewController {
    private let bookList = BehaviorSubject<[BookList]>(value: []) // 초기 선언이므로 빈 배열 !
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BookList"

        
        self.refreshControl = UIRefreshControl()
        let refreshControl = self.refreshControl!
        refreshControl.backgroundColor = .white
        refreshControl.tintColor = .black

        refreshControl.attributedTitle = NSAttributedString(string: "당겨서 새로고침")
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)

        tableView.register(BookListCell.self, forCellReuseIdentifier: "BookListCell")
        tableView.rowHeight = 80

    }

    // UI 안쓰니까 .global 사용 (Rx - Binding으로 처리가능)
    @objc func refresh() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            self.fetchBookList(of: "books")
        }
    }

    func fetchBookList(of fetchedbookList: String) {
        Observable.from([fetchedbookList])
        // 배열의 인덱스를 하나하나 방출
        .map { fetchedbookList -> URL in
            // 타입을 변경할 때도 map이 유용하다. (Array -> URL)

            print("fetchedbookList: \(fetchedbookList) thread in fetchedbookList: \(Thread.isMainThread)")

            return URL(string: "https://kxcoding-study.azurewebsites.net/api/\(fetchedbookList)")!
        }
        //MARK: - Request
        .map { url -> URLRequest in
            print("url: \(url) thread in url: \(Thread.isMainThread)")
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            return request
        }
        // URL -> URLRequest
        .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in

            print("request: \(request) thread in request: \(Thread.isMainThread)")

            return URLSession.shared.rx.response(request: request)
        }
        // Tuple의 형태의 Observable 시퀀스로 변환 Observable<(response,data)>.  ... Observable<Int> 처럼
        //MARK: - Response
        .filter { response, _ in
            // Tuple 내에서 response만 받기 위해 _ 표시

            print("response: \(response) thread in response: \(Thread.isMainThread)")

            return 200..<300 ~= response.statusCode
            // responds.statusCode가 해당범위에 해당하면 true
        }
            .map { _, data -> [BookList] in

            print("data: \(data) thread in data: \(Thread.isMainThread)")

            let decoder = JSONDecoder()
            if let json = try? decoder.decode(BookList.self, from: data) {
                print("type: \(type(of: [json]))")
//                print("type(of: [json]): \(type(of: [json]))")
//                return BookList(list: json.list, totalCount: json.totalCount, code: json.code, message: json.message)
                return [json]
            }
            throw SimpleError()
        }
            .filter { objects in // 빈 Array(연결 실패)는 안 받을래 !

            print(" * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * ")
            print("objects: \(objects) thread in objects: \(Thread.current)")
            print(" * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * ")
                
            return objects.count > 0
        }
        .map { objects in // compactMap: 1차원 배열에서 nil을 제거하고 옵셔널 바인딩
            //throw SimpleError() //MARK: map안에서의 에러 표현
            
            return objects.compactMap { dic -> BookList? in

                print(" * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * ")
                print("dic: \(dic) thread in dic: \(Thread.current)") //MARK: 몇 번 쓰레드에서 돌아가는 지 까지 확인 가능 !
                print(" * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * ")

//                guard let id = dic["id"] as? Int,
//                    let name = dic["name"] as? String,
//                    let description = dic["description"] as? String,
//                    let stargazersCount = dic["stargazers_count"] as? Int,
//                    let language = dic["language"] as? String else {
//                    return nil
//                }


                
                return BookList(list: dic.list, totalCount: dic.totalCount, code: dic.code, message: dic.message)
            }
        }
            .subscribe(on: ConcurrentDispatchQueueScheduler(queue: .global())) // Observable 자체 Thread 변경
        .observe(on: MainScheduler.instance) // 이후 subsribe의 Thread 변경
        .subscribe { event in // MARK: 에러처리에 용이한 subscribe 트릭
            switch event {
            case .next(let newBookList):
                print("newBookList: \(newBookList), thread in newBookList: \(Thread.isMainThread)")
                self.bookList.onNext(newBookList)
//                print(type(of: newBookList))
//                print(self.bookList.values)
//                print("self.bookList is \(self.bookList)")
                // BehaviorSubject에 이벤트 발생
                self.tableView.reloadData()
                self.refreshControl?.endRefreshing()
            case .error(let error):
                print("error: \(error), thread: \(Thread.isMainThread)")
                self.refreshControl?.endRefreshing()
                self.alertAction()
            case .completed:
                print("completed")
            }
        }
            .disposed(by: disposeBag)
    }

    func alertAction() {
        let optionMenu = UIAlertController(title: "에러", message: "네트워크 상태를 확인하세요.", preferredStyle: .alert)

        let Action = UIAlertAction(title: "확인", style: .cancel, handler: {
            (alert: UIAlertAction!) -> Void in
            print("확인")
        })
        optionMenu.addAction(Action)
        self.present(optionMenu, animated: true, completion: nil)
    }
}

extension ViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        do {
            return try bookList.value().count
        } catch {
            return 0
        } // BehaviorSubject의 특징 이용하여 값만 가져오기(.count와 동일)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BookListCell", for: indexPath) as? BookListCell else { return UITableViewCell() }

        var currentBookList: BookList? {
            do {
                return try bookList.value()[indexPath.row]
            } catch {
                return nil
            }
        }

        cell.bookList = currentBookList

        return cell
    }

}
