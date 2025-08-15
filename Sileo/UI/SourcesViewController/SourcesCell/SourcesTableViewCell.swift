//
//  SourcesTableViewCell.swift
//  Sileo
//
//  Created by CoolStar on 7/27/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import Evander

class SourcesTableViewCell: BaseSubtitleTableViewCell {
    
    static var repoImageUpdate = Notification.Name("Sileo.RepoImageUpdate")
    let showTotalPackages: Bool = UserDefaults.standard.bool(forKey: "ShowPackageCount", fallback: false)
    
    public weak var repo: Repo? = nil {
        didSet {
            if let repo = repo {
                self.title = repo.displayName
                self.subtitle = repo.displayURL
                self.progress = repo.totalProgress
                self.image(repo)
                installedLabel.text = "\(showTotalPackages ? repo.packageArray.count : repo.installed?.count ?? 0)"
            } else {
                self.title = String(localizationKey: "All_Packages.Title")
                self.subtitle = String(localizationKey: "All_Packages.Cell_Subtitle")
                self.icon = UIImage(named: "All Packages")
                self.progress = 0
                installedLabel.text = "\(showTotalPackages ? PackageListManager.shared.allPackagesArray.count : PackageListManager.shared.installedPackages.count)"
            }
        }
    }
    public var installedLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        if let image = UIImage(named: "Chevron") {
            let imageView = UIImageView(image: image)
            imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = UIColor(red: 105.0/255.0, green: 115.0/255.0, blue: 122.0/255.0, alpha: 1)
            accessoryView = imageView
        }
        
        contentView.addSubview(installedLabel)
        installedLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.trailingAnchor.constraint(equalTo: installedLabel.trailingAnchor, constant: 7.5).isActive = true
        installedLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        installedLabel.font = UIFont.systemFont(ofSize: 12)
        installedLabel.textColor = UIColor(red: 125.0/255.0, green: 135.0/255.0, blue: 142.0/255.0, alpha: 1)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.repo = nil
    }

    public func image(_ repo: Repo) {
        // Quite frankly the backend here sucks ass, so if you open the sources page too quick after launching the image will not be set
        // This will pull it from local cache in the event that we're too quick. If doesn't exist in Cache, show the default icon
        if repo.url?.host == "apt.thebigboss.org" {
            let url = StoreURL("deprecatedicons/BigBoss@\(Int(UIScreen.main.scale))x.png")!
            let cache = EvanderNetworking.imageCache(url, scale: UIScreen.main.scale)
            if let image = cache.1 {
                self.icon = image
                return
            }
        }
        if let icon = repo.repoIcon {
            self.icon = icon
            return
        }
        let scale = Int(UIScreen.main.scale)
        for i in (1...scale).reversed() {
            let filename = i == 1 ? CommandPath.RepoIcon : "\(CommandPath.RepoIcon)@\(i)x"
            if let iconURL = URL(string: repo.repoURL)?
                .appendingPathComponent(filename)
                .appendingPathExtension("png") {
                let cache = EvanderNetworking.imageCache(iconURL, scale: CGFloat(i))
                if let image = cache.1 {
                    self.icon = image
                    return
                }
            }
        }
        self.icon = UIImage(named: "Repo Icon")
    }
}
