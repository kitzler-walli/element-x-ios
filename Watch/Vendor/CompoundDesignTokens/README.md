# CompoundDesignTokens (watchOS copy)

The SwiftUI parts of [compound-design-tokens](https://github.com/element-hq/compound-design-tokens) v11.3.1,
vendored for the watch app because the package's UIKit tokens don't build for watchOS.

Update by copying the same files from `assets/ios/swift` of the version used in `compound-ios/Package.swift`.

watchOS ignores the dark appearance in asset catalogs, so after copying run `make_dark_only.py` to keep only the dark colours.
