//
//  BookListCell.swift
//  URLSession+Rx
//
//  Created by mobile on 2023/02/01.
//

import UIKit
import SnapKit

class BookListCell: UITableViewCell {
    var bookList: List?

    var titleLabel = UILabel()
    var descriptionLabel = UILabel()
    var cellCount = BookCount.value
    
    override func layoutSubviews() {
        super.layoutSubviews()
        [
            titleLabel, descriptionLabel
        ].forEach {
            contentView.addSubview($0)
        }
        
        guard let bookList = bookList else { return }
        titleLabel.text = bookList.title
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        
        descriptionLabel.text = bookList.description
        descriptionLabel.font = .systemFont(ofSize: 16)
        descriptionLabel.textColor = .lightGray
        descriptionLabel.numberOfLines = 1
        
        titleLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(18)
            // superView의 안쪽 set을 18로 !
        }
        
        descriptionLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(10)
            $0.leading.equalTo(titleLabel.snp.leading)
            $0.trailing.equalTo(titleLabel.snp.trailing)
        }
    }
}
