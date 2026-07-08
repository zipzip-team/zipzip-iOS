//
//  Route.swift
//  Alty-iOS
//
//  Created by 성환 on 6/29/26.
//

import Foundation

enum Route: Hashable {
    case filter
    case filterResult([AppliedFilter])
    case photoInfoEdit(PhotoMetadata)
    case photoDetail(Photo)
}
