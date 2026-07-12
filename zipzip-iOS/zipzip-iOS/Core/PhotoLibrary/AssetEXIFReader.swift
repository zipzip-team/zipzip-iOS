//
//  AssetEXIFReader.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/11/26.
//

import ImageIO
@preconcurrency import Photos

nonisolated enum AssetEXIFReader {
    /// 사진 원본 EXIF의 TIFF Make/Model(촬영 기기 정보)을 읽는다. 정보가 없으면 nil.
    static func deviceInfo(for asset: PHAsset) async -> (make: String?, model: String?) {
        // 스크린샷 등 촬영 기기 정보가 없는 사진은 원본을 읽지 않고 건너뛴다.
        guard !asset.mediaSubtypes.contains(.photoScreenshot) else { return (nil, nil) }

        guard let url = await fullSizeImageURL(for: asset),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        else { return (nil, nil) }

        return (
            cleaned(tiff[kCGImagePropertyTIFFMake] as? String),
            cleaned(tiff[kCGImagePropertyTIFFModel] as? String)
        )
    }

    private static func fullSizeImageURL(for asset: PHAsset) async -> URL? {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = false
        return await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            asset.requestContentEditingInput(with: options) { input, _ in
                continuation.resume(returning: input?.fullSizeImageURL)
            }
        }
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}
