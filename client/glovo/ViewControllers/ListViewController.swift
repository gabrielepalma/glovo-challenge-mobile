import UIKit
import RxSwift
import SnapKit
import RealmSwift

class City {
    var name: String
    var code: String
    var countryCode: String
    var countryName: String
    init(code: String, name: String, countryCode: String, countryName: String) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.code = code
        self.name = name
    }
}

final class ListViewController: UIViewController {

    private var realmConfiguration: Realm.Configuration
    private var citySyncer: Syncer<CityObject>
    private var countrySyncer: Syncer<CountryObject>
    
    private var disposeBag = DisposeBag()
    private let reuseIdentifier = "CityCell"
    private let refreshControl = UIRefreshControl()
    private var datasource = [[City]]()
    private var tableView = UITableView()

    public var selectionConfirmed: ((String) -> ())?

    init(realmConfiguration: Realm.Configuration,
         citySyncer: Syncer<CityObject>,
         countrySyncer: Syncer<CountryObject>)
    {
        self.realmConfiguration = realmConfiguration
        self.citySyncer = citySyncer
        self.countrySyncer = countrySyncer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Select City"
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view)
            make.left.equalTo(view)
            make.right.equalTo(view)
            make.bottom.equalTo(view)
        }

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.separatorStyle = .none
        tableView.refreshControl = refreshControl
        tableView.delegate = self
        tableView.dataSource = self

        let refresh = refreshControl.rx.controlEvent(.valueChanged)
        refresh.bind(onNext: { [countrySyncer, citySyncer] in
            countrySyncer.scheduleSyncronization()
            citySyncer.scheduleSyncronization()
        }).disposed(by: disposeBag)

        Observable
            .combineLatest(
                citySyncer.isSyncing.asObservable(),
                countrySyncer.isSyncing.asObservable())
            .map { (citySycing, countrySyncing) -> Bool in
                return citySycing || countrySyncing
            }
            .filter { (anySyncing) -> Bool in
                return !anySyncing
            }
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [refreshControl] (_) in
                refreshControl.endRefreshing()
            })
            .disposed(by: disposeBag)

        if let realm = try? Realm(configuration: Realm.Configuration.forGlovo()) {
            let cities = realm.objects(CityObject.self)
            Observable
                .changeset(from: cities)
                .subscribe({ [weak self] (_) in
                    // Changes should be rare, skipping animations should be good enough
                    self?.setupDataSource()
                    self?.tableView.reloadData()
                })
                .disposed(by: disposeBag)
        }
    }

    func setupDataSource() {
        if let realm = try? Realm(configuration: Realm.Configuration.forGlovo()) {

            let sortProperties = [SortDescriptor(keyPath: "countryCode"), SortDescriptor(keyPath: "name")]
            let cities = realm.objects(CityObject.self).sorted(by: sortProperties)

            var countryCode = ""
            var countryName = ""
            var datasource = [[City]]()
            var current = [City]()
            for obj in cities {
                if obj.countryCode == countryCode {
                    let city = City(code: obj.code, name: obj.name, countryCode: countryCode, countryName:countryName)
                    current.append(city)
                }
                else {
                    datasource.append(current)
                    current = [City]()
                    countryCode = obj.countryCode
                    countryName = realm.object(ofType: CountryObject.self, forSynchronizationId: countryCode)?.name ?? countryCode
                    let city = City(code: obj.code, name: obj.name, countryCode: countryCode, countryName:countryName)
                    current.append(city)
                }
            }
            datasource.append(current)
            self.datasource = datasource
        }
    }
}

extension ListViewController : UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selected = datasource[indexPath.section][indexPath.row].code
        if let selectionConfirmed = selectionConfirmed {
            selectionConfirmed((selected))
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return datasource[section].first?.countryName
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) ?? UITableViewCell()
        cell.textLabel?.text = datasource[indexPath.section][indexPath.row].name
        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return datasource.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datasource[section].count
    }

}
