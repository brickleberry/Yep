//
//  ImageCache.swift
//  Yep
//
//  Created by NIX on 15/3/31.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import Realm
import MapKit

class ImageCache {
    static let sharedInstance = ImageCache()

    var cache = NSCache()

    func imageOfMessage(message: Message, withSize size: CGSize, tailDirection: MessageImageTailDirection, completion: (UIImage) -> ()) {

        let imageKey = "image-\(message.messageID)-\(message.localAttachmentName)-\(message.attachmentURLString)"

        // 先看看缓存
        if let image = cache.objectForKey(imageKey) as? UIImage {
            completion(image)

        } else {

            var fileName = message.localAttachmentName
            if message.mediaType == MessageMediaType.Video.rawValue {
                fileName = message.localThumbnailName
            }

            var imageURLString = message.attachmentURLString
            if message.mediaType == MessageMediaType.Video.rawValue {
                imageURLString = message.thumbnailURLString
            }

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {

                if !fileName.isEmpty {
                    if
                        let imageFileURL = NSFileManager.yepMessageImageURLWithName(fileName),
                        let image = UIImage(contentsOfFile: imageFileURL.path!) {

                            let messageImage = image.bubbleImageWithTailDirection(tailDirection, size: size)

                            self.cache.setObject(messageImage, forKey: imageKey)
                            
                            completion(messageImage)

                            return
                    }
                }

                // 下载

                if imageURLString.isEmpty {
                    completion(UIImage())

                    return
                }

                if
                    let url = NSURL(string: imageURLString),
                    let data = NSData(contentsOfURL: url) {
                        if let image = UIImage(data: data) {

                            let messageImageName = NSUUID().UUIDString

                            let messageImageURL = NSFileManager.saveMessageImageData(data, withName: messageImageName)

                            dispatch_async(dispatch_get_main_queue()) {
                                let realm = message.realm
                                realm.beginWriteTransaction()

                                if message.mediaType == MessageMediaType.Image.rawValue {
                                    message.localAttachmentName = messageImageName

                                } else if message.mediaType == MessageMediaType.Video.rawValue {
                                    message.localThumbnailName = messageImageName
                                }

                                realm.commitWriteTransaction()
                            }

                            let messageImage = image.bubbleImageWithTailDirection(tailDirection, size: size)
                            
                            self.cache.setObject(messageImage, forKey: imageKey)
                            
                            completion(messageImage)
                        }
                }
            }

        }
    }

    func mapImageOfMessage(message: Message, withSize size: CGSize, tailDirection: MessageImageTailDirection, completion: (UIImage) -> ()) {
        let imageKey = "mapImage-\(message.messageID)"

        // 先看看缓存
        if let image = cache.objectForKey(imageKey) as? UIImage {
            completion(image)

        } else {

            if let coordinate = message.coordinate {
                let options = MKMapSnapshotOptions()
                options.scale = UIScreen.mainScreen().scale
                options.size = size

                let locationCoordinate = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude)
                options.region = MKCoordinateRegionMakeWithDistance(locationCoordinate, 500, 500)

                let mapSnapshotter = MKMapSnapshotter(options: options)

                mapSnapshotter.startWithCompletionHandler { (snapshot, error) -> Void in
                    if error == nil {
                        let mapImage = snapshot.image.bubbleImageWithTailDirection(tailDirection, size: size)

                        self.cache.setObject(mapImage, forKey: imageKey)

                        completion(mapImage)
                    }
                }
            }
        }
    }
}