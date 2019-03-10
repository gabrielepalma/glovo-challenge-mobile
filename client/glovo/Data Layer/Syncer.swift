import Foundation
import RxSwift
import RealmSwift
import PromiseKit
import RxRealm
import Reachability
import RxReachability
import RxCocoa

public protocol SyncerProtocol {
    var isSyncing: Driver<Bool> { get }
    func activate()
    func scheduleSyncronization()
    func startRefreshTimer(period : RxTimeInterval)
    func stopRefreshTimer()
}

public class Syncer <T : Syncable> : SyncerProtocol {
    let realmConfiguration : Realm.Configuration

    var isReachable: Observable<Bool> {
        return reachability.rx.isReachable.startWith(reachability.connection != .none)
    }

    private let networkClient : NetworkClient<T>
    private let reachability : Reachability

    private let syncQueue : DispatchQueue
    private let syncScheduler : SerialDispatchQueueScheduler

    private var disposeBag = DisposeBag()

    private let isSyncingInternal = BehaviorRelay<Bool>(value: false)
    private let hasPendingChanges = BehaviorRelay<Bool>(value: false)
    private let isSyncScheduled = BehaviorRelay<Bool>(value: false)
    private let lastSyncError: BehaviorRelay<Error?> = BehaviorRelay(value: nil)

    public init(networkClient : NetworkClient<T>, realmConfiguration : Realm.Configuration, reachability : Reachability) {
        self.networkClient = networkClient
        self.realmConfiguration = realmConfiguration
        self.reachability = reachability
        self.syncQueue = DispatchQueue.global(qos: .userInitiated)
        self.syncScheduler = SerialDispatchQueueScheduler(queue: syncQueue, internalSerialQueueName: "glovo.syncer")
    }

    private func runSynchronizationFlow() {
        isSyncingInternal.accept(true)
        downstreamChanges().done { _ in
            self.lastSyncError.accept(nil)
        }.catch { (error) in
            self.lastSyncError.accept(error)
        }.finally {
            self.isSyncScheduled.accept(false)
            self.isSyncingInternal.accept(false)
        }
    }
    
    private func downstreamChanges() -> Promise<Void> {
        let configuration = self.realmConfiguration
        return networkClient.fetchAll().then(on: syncQueue) { (dtos) -> Promise<Void> in
            // Processing DTOs from network response
            do {
                let realm = try Realm(configuration: configuration)
                var toBeRemoved = Set(realm.objects(T.self))
                try realm.write {
                    for dto in dtos {
                        let syncIdentifier = dto.syncIdentifier()
                        if let item = realm.object(ofType: T.self, forSynchronizationId:syncIdentifier) {
                            // Item already in store, updating
                            toBeRemoved.remove(item)
                            dto.update(object: item)
                            realm.add(item, update: true)
                        } else {
                            // New item was found, adding
                            let item = T()
                            dto.update(object: item)
                            realm.add(item)
                        }
                    }
                    // Items were not found, removing
                    realm.delete(toBeRemoved)
                }
                return Promise.value(())
            } catch let error {
                return Promise(error: error)
            }
        }
    }
    
    private func subscribeSynchronization() {
        Observable
            .combineLatest(
                isSyncScheduled.asObservable().distinctUntilChanged(),
                isReachable.distinctUntilChanged(),
                isSyncingInternal.asObservable().distinctUntilChanged())
            .map { (isSyncScheduled, isReachable, isSyncingInternal) -> Bool in
                return !isSyncingInternal && isReachable && isSyncScheduled
            }
            .filter { (shouldSync) -> Bool in
                return shouldSync
            }
            .throttle(3, scheduler: syncScheduler)
            .observeOn(syncScheduler)
            .subscribe(onNext: { [weak self] (_) in
                self?.runSynchronizationFlow()
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Public
    public func scheduleSyncronization() {
        isSyncScheduled.accept(true)
    }

    public var isSyncing: Driver<Bool> {
        get {
            return isSyncingInternal.asDriver()
        }
    }

    public func activate() {
        disposeBag = DisposeBag()
        subscribeSynchronization()
    }

    // MARK: Refresh polling
    private var timerDisposeBag : DisposeBag?
    public func startRefreshTimer(period : RxTimeInterval = 30) {
        timerDisposeBag = DisposeBag()
        if let timerDisposeBag = timerDisposeBag  {
            Observable<Int64>
                .timer(period, period: period, scheduler: MainScheduler.instance).subscribe { [weak self] _ in
                    self?.scheduleSyncronization()
                }
                .disposed(by: timerDisposeBag)
        }
    }

    public func stopRefreshTimer() {
        timerDisposeBag = nil
    }
}

extension Realm {
    public func object<T: Syncable>(ofType type: T.Type, forSynchronizationId syncId: String) -> T? {
        return self.objects(T.self).filter( { $0.syncIdentifier == syncId } ).first
    }
}
