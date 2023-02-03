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
    private let bookList = PublishSubject<BookList>() // 초기 선언이므로 빈 배열 !
    private let list = BehaviorSubject<[List]>(value: [])
    private let disposeBag = DisposeBag()

    let cellData = PublishSubject<[BookListCellData]>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BookList"
    
        self.tableView.delegate = nil
        self.tableView.dataSource = nil
        
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
//        DispatchQueue.global(qos: .background).async { [weak self] in
//            guard let self = self else { return }
//
//            self.fetchBookList(of: "books")
//        }
        bind()
        fetchBookList(of: "books")
    }

    func fetchBookList(of fetchedbookList: String) {
        Observable.from([fetchedbookList])
        // 배열의 인덱스를 하나하나 방출
        .map { fetchedbookList -> URL in
            // 타입을 변경할 때도 map이 유용하다. (Array -> URL)
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
            return URLSession.shared.rx.response(request: request)
        }
        // Tuple의 형태의 Observable 시퀀스로 변환 Observable<(response,data)>.  ... Observable<Int> 처럼
        //MARK: - Response
        .filter { response, _ in
            // Tuple 내에서 response만 받기 위해 _ 표시
            return 200..<300 ~= response.statusCode
            // responds.statusCode가 해당범위에 해당하면 true
        }
            .map { _, data -> BookList in
            let decoder = JSONDecoder()
            if let json = try? decoder.decode(BookList.self, from: data) {
                return json
            }
            throw SimpleError()
        } // MARK: - 배열만 뽑아내는 Tric
        .map { objects -> [List] in // compactMap: 1차원 배열에서 nil을 제거하고 옵셔널 바인딩
            //throw SimpleError() //MARK: map안에서의 에러 표현

            return objects.list.compactMap { dic -> List? in

                print("Pleeeease: \(List(id: dic.id, title: dic.title, description: dic.description, yes24Link: dic.yes24Link, publicationDate: dic.publicationDate))")

                return List(id: dic.id, title: dic.title, description: dic.description, yes24Link: dic.yes24Link, publicationDate: dic.publicationDate)
            }
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(queue: .global())) // Observable 자체 Thread 변경
        .observe(on: MainScheduler.instance) // 이후 subsribe의 Thread 변경
        .subscribe { event in // MARK: 에러처리에 용이한 subscribe 트릭
            switch event {
            case .next(let newBookList):
                print("newBookList: \(newBookList), thread in newBookList: \(Thread.isMainThread)")
                self.list.onNext(newBookList)
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
    
    private func bind() {
        cellData
            .asDriver(onErrorJustReturn: []) // = asObservable , 만약 에러가 발생하면 에러를 발생시켜 !
            .drive(self.tableView.rx.items) { tv, row, data in
                let index = IndexPath(row: row, section: 0)
                let cell = tv.dequeueReusableCell(withIdentifier: "BookListCell", for: index) as! BookListCell
                cell.setData(data) // [ ] 형태의 PublishSubject인 data를 받으면 setData를 통해 뿌려줌(= cellForRowAt) delegate를 rx로 대체.
                return cell
            }
            .disposed(by: disposeBag)
    }
}


//extension ViewController {
//    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        do {
//            return try list.value().count
//        } catch {
//            return 0
//        } // BehaviorSubject의 특징 이용하여 값만 가져오기(.count와 동일)
//    }
//
//    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BookListCell", for: indexPath) as? BookListCell else { return UITableViewCell() }
//
//        var currentBookList: List? {
//            do {
//                return try list.value()[indexPath.row]
//            } catch {
//                return nil
//            }
//        }
//
//        cell.bookList = currentBookList
//
//        return cell
//    }
//}

