//
//  PanelView.swift
//  glovo
//
//  Created by i335287 on 08/03/2019.
//  Copyright © 2019 Gabriele Palma. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

enum PanelViewState {
    case outOfBounds
    case cityInfo(code: String, name: String, country: String, loadingData: Bool)
    case cityDetail(code: String, name: String, country: String, currency: String, timeZone: String, language: String, enabled: Bool, busy: Bool)
}

class PanelView: UIView {
    public var state = BehaviorRelay<PanelViewState>(value: .outOfBounds)
    public var searchCallback: (() -> ())?
    public static let minimumHeight = 40.0 + customLayoutMargins * 3 + 21.0

    private static let customLayoutMargins: CGFloat = 12.0
    private let largerFont: CGFloat = 22.0
    private let smallerFont: CGFloat = 10.0


    private var cityNameLabel = UILabel()
    private var countryNameLabel = UILabel()
    private var timeZoneLabel = UILabel()
    private var currencyLabel = UILabel()
    private var languageLabel = UILabel()
    private var enabledLabel = UILabel()
    private var busyLabel = UILabel()
    private var waitIndicator = UIActivityIndicatorView()
    private var searchButton = UIButton()

    private var compactConstraint : NSLayoutConstraint?
    private var extendedConstraint : NSLayoutConstraint?

    private let disposeBag = DisposeBag()

    init() {
        super.init(frame: .zero)
        state.subscribe(onNext: { [weak self] state in
            guard let self = self else {
                return
            }
            switch state {
            case .outOfBounds:
                self.toggleConstraints(isCompact: true)
                self.toggleWaitingView(isLoading: false)
                self.setCityInfo(cityName: "Not found", countryName: "")
                self.clearDetail()
                break
            case .cityInfo(_, let name, let country, let loadingData):
                self.toggleConstraints(isCompact: false)
                self.toggleWaitingView(isLoading: loadingData)
                self.setCityInfo(cityName: name, countryName: country)
                self.clearDetail()
                break
            case .cityDetail(_, let name, let country, let currency, let timeZone, let language, let enabled, let busy):
                self.toggleConstraints(isCompact: false)
                self.toggleWaitingView(isLoading: false)
                self.setCityInfo(cityName: name, countryName: country)
                self.currencyLabel.text = currency
                self.timeZoneLabel.text = timeZone
                self.languageLabel.text = language
                self.enabledLabel.text = enabled ? "ACTIVE" : "INACTIVE"
                self.busyLabel.text = busy ? "BUSY" : "NOT BUSY"
                break
            }
            UIView.animate(withDuration: 0.2, animations: {
                self.layoutIfNeeded()
            })

        }).disposed(by: disposeBag)
    }

    public func toggleWaitingView(isLoading: Bool) {
        if isLoading {
            self.waitIndicator.startAnimating()
        }
        else {
            self.waitIndicator.stopAnimating()
        }
    }

    public func toggleConstraints(isCompact: Bool) {
        self.compactConstraint?.isActive = isCompact
        self.extendedConstraint?.isActive = !isCompact
    }

    public func setCityInfo(cityName: String, countryName: String) {
        self.cityNameLabel.text = cityName
        self.countryNameLabel.text = countryName
    }

    public func clearDetail() {
        self.currencyLabel.text = ""
        self.timeZoneLabel.text = ""
        self.languageLabel.text = ""
        self.enabledLabel.text = ""
        self.busyLabel.text = ""
    }

    public func configureInternalConstraints() {
        addSubview(cityNameLabel)
        addSubview(countryNameLabel)
        addSubview(timeZoneLabel)
        addSubview(currencyLabel)
        addSubview(languageLabel)
        addSubview(enabledLabel)
        addSubview(busyLabel)
        addSubview(waitIndicator)
        addSubview(searchButton)

        self.backgroundColor = UIColor.white
        cityNameLabel.snp.makeConstraints { make in
            make.top.equalTo(self).offset(PanelView.customLayoutMargins)
            make.left.equalTo(self).offset(PanelView.customLayoutMargins)
        }
        cityNameLabel.text = "Not found"
        cityNameLabel.font = UIFont.systemFont(ofSize: largerFont)
        countryNameLabel.snp.makeConstraints { make in
            make.top.equalTo(cityNameLabel.snp.bottom).offset(PanelView.customLayoutMargins)
            make.left.equalTo(cityNameLabel)
        }
        currencyLabel.snp.makeConstraints { make in
            make.top.equalTo(countryNameLabel.snp.bottom).offset(PanelView.customLayoutMargins)
            make.left.equalTo(cityNameLabel)
        }
        currencyLabel.font = UIFont.systemFont(ofSize: smallerFont)
        languageLabel.snp.makeConstraints { make in
            make.top.equalTo(currencyLabel)
            make.right.equalTo(self).offset(-PanelView.customLayoutMargins)
        }
        languageLabel.font = UIFont.systemFont(ofSize: smallerFont)
        enabledLabel.snp.makeConstraints { make in
            make.top.equalTo(currencyLabel.snp.bottom).offset(PanelView.customLayoutMargins)
            make.left.equalTo(cityNameLabel)
        }
        enabledLabel.font = UIFont.systemFont(ofSize: smallerFont)
        busyLabel.snp.makeConstraints { make in
            make.top.equalTo(enabledLabel)
            make.right.equalTo(languageLabel)
        }
        busyLabel.font = UIFont.systemFont(ofSize: smallerFont)
        timeZoneLabel.snp.makeConstraints { make in
            make.top.equalTo(busyLabel.snp.bottom).offset(PanelView.customLayoutMargins)
            make.left.equalTo(cityNameLabel)
        }
        timeZoneLabel.font = UIFont.systemFont(ofSize: smallerFont)
        waitIndicator.snp.makeConstraints { make in
            make.centerY.equalTo(self)
            make.centerX.equalTo(self)
        }
        waitIndicator.hidesWhenStopped = true
        waitIndicator.style = .gray
        waitIndicator.tintColor = UIColor.glovoOrange
        searchButton.snp.makeConstraints { make in
            make.left.equalTo(self).offset(PanelView.customLayoutMargins)
            make.right.equalTo(self).offset(-PanelView.customLayoutMargins)
            make.height.equalTo(40)
            make.bottom.equalTo(self).offset(-PanelView.customLayoutMargins)
        }
        searchButton.setTitleColor(UIColor.black, for: .normal)
        searchButton.setTitle("Search City", for: .normal)
        searchButton.addTarget(self, action: #selector(searchButtonWasTapped), for: .touchUpInside)
        searchButton.backgroundColor = UIColor.glovoOrange
        searchButton.layer.cornerRadius = 5.0

        compactConstraint = NSLayoutConstraint.init(item: searchButton, attribute: .top, relatedBy: .equal, toItem: cityNameLabel, attribute: .bottom, multiplier: 1.0, constant: PanelView.customLayoutMargins)
        extendedConstraint = NSLayoutConstraint.init(item: searchButton, attribute: .top, relatedBy: .equal, toItem: timeZoneLabel, attribute: .bottom, multiplier: 1.0, constant: PanelView.customLayoutMargins)
        compactConstraint?.isActive = true

    }

    @objc func searchButtonWasTapped() {
        if let searchCallback = searchCallback {
            searchCallback()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
