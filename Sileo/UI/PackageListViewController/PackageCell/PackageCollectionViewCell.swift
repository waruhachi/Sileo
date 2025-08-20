//
//  PackageCollectionViewCell.swift
//  Sileo
//
//  Created by CoolStar on 7/30/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Evander
import SwipeCellKit
import UIKit

class PackageCollectionViewCell: SwipeCollectionViewCell {
    @IBOutlet var imageView: UIImageView?
    @IBOutlet var titleLabel: UILabel?
    @IBOutlet var authorLabel: UILabel?
    @IBOutlet var descriptionLabel: UILabel?
    @IBOutlet var separatorView: UIView?
    @IBOutlet var unreadView: UIView?

    var item: CGFloat = 0
    var numberOfItems: CGFloat = 0
    var alwaysHidesSeparator = false
    var stateBadgeView: PackageStateBadgeView?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public var targetPackage: Package? {
        didSet {
            if let targetPackage = targetPackage {
                titleLabel?.text = targetPackage.name
                let repoDisplay =
                    targetPackage.sourceRepo?.displayName ?? targetPackage
                    .source?.host ?? ""
                let versionAndRepo =
                    repoDisplay.isEmpty
                    ? "\(targetPackage.version)"
                    : "\(targetPackage.version) • \(repoDisplay)"
                authorLabel?.text =
                    "\(targetPackage.author?.name ?? "Unknown") • \(versionAndRepo)"
                descriptionLabel?.text = targetPackage.packageDescription

                let url = targetPackage.icon
                EvanderNetworking.image(
                    url: url,
                    condition: { [weak self] in self?.targetPackage?.icon == url
                    },
                    imageView: imageView,
                    fallback: targetPackage.defaultIcon
                )

                titleLabel?.textColor =
                    targetPackage.commercial ? self.tintColor : .sileoLabel
            }
            unreadView?.isHidden = true

            self.accessibilityLabel = String(
                format: String(localizationKey: "Package_By_Author"),
                self.titleLabel?.text ?? "",
                self.authorLabel?.text ?? ""
            )

            self.refreshState()
        }
    }

    public var provisionalTarget: ProvisionalPackage? {
        didSet {
            if let provisionalTarget = provisionalTarget {
                titleLabel?.text = provisionalTarget.name ?? ""
                let repoDisplay =
                    provisionalTarget.repository.uri.host
                    ?? provisionalTarget.repository.slug
                let versionAndRepo =
                    "\(provisionalTarget.version) • \(repoDisplay)"
                authorLabel?.text =
                    "\(provisionalTarget.author?.name ?? "") • \(versionAndRepo)"
                descriptionLabel?.text = provisionalTarget.description

                let url = provisionalTarget.icon
                EvanderNetworking.image(
                    url: url,
                    condition: { [weak self] in
                        self?.provisionalTarget?.icon == url
                    },
                    imageView: imageView,
                    fallback: provisionalTarget.defaultIcon
                )

                titleLabel?.textColor = .sileoLabel
            }
            unreadView?.isHidden = true

            self.accessibilityLabel = String(
                format: String(localizationKey: "Package_By_Author"),
                self.titleLabel?.text ?? "",
                self.authorLabel?.text ?? ""
            )

            self.refreshState()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        self.selectedBackgroundView = UIView()
        self.selectedBackgroundView?.backgroundColor = UIColor.lightGray
            .withAlphaComponent(0.25)

        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.delegate = self

        stateBadgeView = PackageStateBadgeView(frame: .zero)
        stateBadgeView?.translatesAutoresizingMaskIntoConstraints = false
        stateBadgeView?.state = .installed

        if let stateBadgeView = stateBadgeView {
            self.contentView.addSubview(stateBadgeView)

            if let imageView = imageView {
                stateBadgeView.centerXAnchor.constraint(
                    equalTo: imageView.rightAnchor
                ).isActive = true
                stateBadgeView.centerYAnchor.constraint(
                    equalTo: imageView.bottomAnchor
                ).isActive = true
            }
        }

        weak var weakSelf = self
        NotificationCenter.default.addObserver(
            weakSelf as Any,
            selector: #selector(updateSileoColors),
            name: SileoThemeManager.sileoChangedThemeNotification,
            object: nil
        )
    }

    @objc func updateSileoColors() {
        if !(targetPackage?.commercial ?? false) {
            titleLabel?.textColor = .sileoLabel
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var numberOfItemsInRow = CGFloat(1)
        if UIDevice.current.userInterfaceIdiom == .pad
            || UIApplication.shared.statusBarOrientation.isLandscape
        {
            numberOfItemsInRow = (self.superview?.bounds.width ?? 0) / 300
        }

        if alwaysHidesSeparator
            || ceil((item + 1) / numberOfItemsInRow)
                == ceil(numberOfItems / numberOfItemsInRow)
        {
            separatorView?.isHidden = true
        } else {
            separatorView?.isHidden = false
        }
    }

    func setTargetPackage(_ package: Package, isUnread: Bool) {
        self.targetPackage = package
        unreadView?.isHidden = !isUnread
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()

        if targetPackage?.commercial ?? false {
            titleLabel?.textColor = self.tintColor
        }

        unreadView?.backgroundColor = self.tintColor
    }

    @objc func refreshState() {
        guard let targetPackage = targetPackage else {
            stateBadgeView?.isHidden = true
            return
        }
        stateBadgeView?.isHidden = false
        let queueState = DownloadManager.shared.find(package: targetPackage)
        switch queueState {
        case .installations:
            let isInstalled =
                PackageListManager.shared.installedPackage(
                    identifier: targetPackage.package
                ) != nil
            stateBadgeView?.state =
                isInstalled ? .reinstallQueued : .installQueued
        case .upgrades:
            stateBadgeView?.state = .updateQueued
        case .uninstallations:
            stateBadgeView?.state = .deleteQueued
        default:
            let isInstalled =
                PackageListManager.shared.installedPackage(
                    identifier: targetPackage.package
                ) != nil
            stateBadgeView?.state = .installed
            stateBadgeView?.isHidden = !isInstalled
        }
    }

}

extension PackageCollectionViewCell: SwipeCollectionViewCellDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        editActionsForItemAt indexPath: IndexPath,
        for orientation: SwipeActionsOrientation
    ) -> [SwipeAction]? {
        // Different actions depending on where we are headed
        // Also making sure that the set package actually exists
        if let provisionalPackage = provisionalTarget {
            let repo = provisionalPackage.repository
            guard orientation == .right else { return nil }
            if !RepoManager.shared.hasRepo(with: repo.uri) {
                return [addRepo(provisionalPackage)]
            }
            return nil
        }
        guard let package = targetPackage,
            UserDefaults.standard.bool(forKey: "SwipeActions", fallback: true)
        else { return nil }
        var actions = [SwipeAction]()
        let queueFound = DownloadManager.shared.find(package: package)
        // We only want delete if we're going left, and only if it's in the queue
        if orientation == .left {
            if queueFound != .none {
                actions.append(cancelAction(package))
            }
            return actions
        }
        // Check if the package is actually installed
        if let installedPackage = PackageListManager.shared.installedPackage(
            identifier: package.package
        ) {
            let repo = RepoManager.shared.repoList.first(where: {
                $0.rawEntry == package.sourceFile
            })
            // Check we have a repo for the package
            if queueFound != .uninstallations {
                actions.append(uninstallAction(package))
            }
            if package.filename != nil && repo != nil {
                // Check if can be updated
                if DpkgWrapper.isVersion(
                    package.version,
                    greaterThan: installedPackage.version
                ) {
                    if queueFound != .upgrades {
                        actions.append(upgradeAction(package))
                    }
                } else {
                    // Only add re-install if it can't be updated
                    if queueFound != .installations {
                        actions.append(reinstallAction(package))
                    }
                }
            }
        } else {
            if queueFound != .installations {
                actions.append(getAction(package))
            }
        }
        return actions
    }

    func collectionView(
        _ collectionView: UICollectionView,
        editActionsOptionsForItemAt indexPath: IndexPath,
        for orientation: SwipeActionsOrientation
    ) -> SwipeOptions {
        var options = SwipeOptions()
        options.expansionStyle = .selection
        return options
    }

    private func addRepo(_ package: ProvisionalPackage) -> SwipeAction {
        let addRepo = SwipeAction(
            style: .default,
            title: String(localizationKey: "Add_Source.Title")
        ) { _, _ in
            if let tabBarController = self.window?.rootViewController
                as? UITabBarController,
                let sourcesSVC = tabBarController.viewControllers?[2]
                    as? UISplitViewController,
                let sourcesNavNV = sourcesSVC.viewControllers[0]
                    as? SileoNavigationController
            {
                tabBarController.selectedViewController = sourcesSVC
                if let sourcesVC = sourcesNavNV.viewControllers[0]
                    as? SourcesViewController
                {
                    sourcesVC.presentAddSourceEntryField(
                        url: package.repository.uri
                    )
                }
            }
            if let package = CanisterResolver.package(package) {
                CanisterResolver.shared.queuePackage(package)
            }
            self.hapticResponse()
            self.hideSwipe(animated: true)
        }
        addRepo.backgroundColor = UIColor.systemPink
        addRepo.image = UIImage(systemNameOrNil: "plus.app")
        return addRepo
    }

    private func cancelAction(_ package: Package) -> SwipeAction {
        let cancel = SwipeAction(
            style: .destructive,
            title: String(localizationKey: "Cancel")
        ) { _, _ in
            DownloadManager.shared.remove(package: package.package)
            DownloadManager.shared.reloadData(recheckPackages: true)
            self.hapticResponse()
            self.hideSwipe(animated: true)
        }
        cancel.image = UIImage(systemNameOrNil: "x.circle")
        return cancel
    }

    private func uninstallAction(_ package: Package) -> SwipeAction {
        let uninstall = SwipeAction(
            style: .destructive,
            title: String(localizationKey: "Package_Uninstall_Action")
        ) { _, _ in
            let queueFound = DownloadManager.shared.find(package: package)
            if queueFound != .none {
                DownloadManager.shared.remove(package: package.package)
            }
            DownloadManager.shared.add(
                package: package,
                queue: .uninstallations
            )
            DownloadManager.shared.reloadData(recheckPackages: true)
            self.hapticResponse()
            self.hideSwipe(animated: true)
        }
        uninstall.image = UIImage(systemNameOrNil: "trash.circle")
        return uninstall
    }

    private func upgradeAction(_ package: Package) -> SwipeAction {
        let update = SwipeAction(
            style: .default,
            title: String(localizationKey: "Package_Upgrade_Action")
        ) { _, _ in
            let queueFound = DownloadManager.shared.find(package: package)
            if queueFound != .none {
                DownloadManager.shared.remove(package: package.package)
            }
            DownloadManager.shared.add(package: package, queue: .upgrades)
            DownloadManager.shared.reloadData(recheckPackages: true)
            self.hapticResponse()
            self.hideSwipe(animated: true)
        }
        update.backgroundColor = .systemBlue
        update.image = UIImage(systemNameOrNil: "icloud.and.arrow.down")
        return update
    }

    private func reinstallAction(_ package: Package) -> SwipeAction {
        let reinstall = SwipeAction(
            style: .default,
            title: String(localizationKey: "Package_Reinstall_Action")
        ) { _, _ in
            let queueFound = DownloadManager.shared.find(package: package)
            if queueFound != .none {
                DownloadManager.shared.remove(package: package.package)
            }
            DownloadManager.shared.add(package: package, queue: .installations)
            DownloadManager.shared.reloadData(recheckPackages: true)
            self.hapticResponse()
            self.hideSwipe(animated: true)
        }
        reinstall.image = UIImage(systemNameOrNil: "arrow.clockwise.circle")
        reinstall.backgroundColor = .systemOrange
        return reinstall
    }

    private func getAction(_ package: Package) -> SwipeAction {
        let install = SwipeAction(
            style: .default,
            title: String(localizationKey: "Package_Get_Action")
        ) { _, _ in
            let queueFound = DownloadManager.shared.find(package: package)
            if queueFound != .none {
                DownloadManager.shared.remove(package: package.package)
            }
            if package.sourceRepo != nil && !package.package.contains("/") {
                if !package.commercial {
                    DownloadManager.shared.add(
                        package: package,
                        queue: .installations
                    )
                    DownloadManager.shared.reloadData(recheckPackages: true)
                } else {
                    self.updatePurchaseStatus(package) {
                        error,
                        provider,
                        purchased in
                        guard let provider = provider else {
                            return self.presentAlert(
                                paymentError: .invalidResponse,
                                title: String(
                                    localizationKey:
                                        "Purchase_Auth_Complete_Fail.Title",
                                    type: .error
                                )
                            )
                        }
                        if let error = error {
                            return self.presentAlert(
                                paymentError: error,
                                title: String(
                                    localizationKey:
                                        "Purchase_Auth_Complete_Fail.Title",
                                    type: .error
                                )
                            )
                        }
                        if purchased {
                            DownloadManager.shared.add(
                                package: package,
                                queue: .installations
                            )
                            DownloadManager.shared.reloadData(
                                recheckPackages: true
                            )
                        } else {
                            if provider.isAuthenticated {
                                self.initatePurchase(
                                    provider: provider,
                                    package: package
                                )
                            } else {
                                DispatchQueue.main.async {
                                    self.authenticate(
                                        provider: provider,
                                        package: package
                                    )
                                }
                            }
                        }
                    }
                }
            }
            self.hapticResponse()
            self.hideSwipe(animated: true)
        }
        if package.commercial {
            install.image = UIImage(systemNameOrNil: "dollarsign.circle")
        } else {
            install.image = UIImage(systemNameOrNil: "square.and.arrow.down")
        }
        install.backgroundColor = .systemGreen
        return install
    }

    private func updatePurchaseStatus(
        _ package: Package,
        _ completion: ((PaymentError?, PaymentProvider?, Bool) -> Void)?
    ) {
        guard let repo = package.sourceRepo else {
            return self.presentAlert(
                paymentError: .noPaymentProvider,
                title: String(
                    localizationKey: "Purchase_Auth_Complete_Fail.Title",
                    type: .error
                )
            )
        }
        PaymentManager.shared.getPaymentProvider(for: repo) { error, provider in
            guard let provider = provider else {
                if let completion = completion {
                    completion(.noPaymentProvider, nil, false)
                }
                return
            }
            if error != nil {
                if let completion = completion {
                    completion(error, provider, false)
                }
                return
            }
            provider.getPackageInfo(forIdentifier: package.package) {
                error,
                info in
                guard let info = info else {
                    if let completion = completion {
                        completion(error, provider, false)
                    }
                    return
                }
                if error != nil {
                    return
                }
                if info.purchased {
                    DownloadManager.shared.add(
                        package: package,
                        queue: .installations
                    )
                    DownloadManager.shared.reloadData(recheckPackages: true)
                    if let completion = completion {
                        completion(nil, provider, true)
                    }
                } else {
                    if let completion = completion {
                        completion(nil, provider, false)
                    }
                }
            }
        }
    }

    private func initatePurchase(provider: PaymentProvider, package: Package) {
        provider.initiatePurchase(forPackageIdentifier: package.package) {
            error,
            status,
            actionURL in
            if status == .cancel { return }
            guard !(error?.shouldInvalidate ?? false) else {
                return self.authenticate(provider: provider, package: package)
            }
            if error != nil || status == .failed {
                self.presentAlert(
                    paymentError: error,
                    title: String(
                        localizationKey: "Purchase_Initiate_Fail.Title",
                        type: .error
                    )
                )
            }
            guard let actionURL = actionURL,
                status != .immediateSuccess
            else {
                return self.updatePurchaseStatus(package, nil)
            }
            DispatchQueue.main.async {
                PaymentAuthenticator.shared.handlePayment(
                    actionURL: actionURL,
                    provider: provider,
                    window: self.window
                ) { error, success in
                    if error != nil {
                        let title = String(
                            localizationKey: "Purchase_Complete_Fail.Title",
                            type: .error
                        )
                        return self.presentAlert(
                            paymentError: error,
                            title: title
                        )
                    }
                    if success {
                        self.updatePurchaseStatus(package, nil)
                    }
                }
            }
        }
    }

    private func authenticate(provider: PaymentProvider, package: Package) {
        PaymentAuthenticator.shared.authenticate(
            provider: provider,
            window: self.window
        ) { error, success in
            if error != nil {
                return self.presentAlert(
                    paymentError: error,
                    title: String(
                        localizationKey: "Purchase_Auth_Complete_Fail.Title",
                        type: .error
                    )
                )
            }
            if success {
                self.updatePurchaseStatus(package, nil)
            }
        }
    }

    private func presentAlert(paymentError: PaymentError?, title: String) {
        DispatchQueue.main.async {
            UIApplication.shared.windows.last?.rootViewController?.present(
                PaymentError.alert(
                    for: paymentError,
                    title: title
                ),
                animated: true,
                completion: nil
            )
        }
    }

    private func hapticResponse() {
        if #available(iOS 13, *) {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        } else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
