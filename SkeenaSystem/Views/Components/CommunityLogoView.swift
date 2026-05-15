//
//  CommunityLogoView.swift
//  SkeenaSystem
//
//  Displays the community logo with a four-tier fallback:
//  1. Persistent on-device cache (CommunityLogoCache) — survives launches,
//     works offline once a community's logo has been seen online at least
//     once. URL-keyed so two communities sharing a logo dedupe automatically.
//  2. Remote URL (AsyncImage) — if config.logoUrl is set and cache misses.
//  3. Bundled asset — Image(config.resolvedLogoAssetName) during load/failure.
//  4. Default "AppLogo" — community-neutral fallback. The asset's underlying
//     image is the Mad Thinker mark, not any specific community's branding.
//
//  No spinner is shown — the bundled asset renders immediately while the
//  remote image loads, so there is no visual flicker.
//

import SwiftUI

struct CommunityLogoView: View {
    let config: CommunityConfig
    var size: CGFloat = 160

    var body: some View {
        Group {
            if let urlString = config.logoUrl, let url = URL(string: urlString) {
                // Tier 1: persistent disk cache. Synchronous read; NSCache
                // memoization in CommunityLogoCache means repeat renders
                // during a session don't re-hit disk.
                if let data = CommunityLogoCache.shared.loadData(for: url),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    // Tier 2: remote fetch. Falls back to bundled on
                    // network failure (which is what an offline launch
                    // before-first-online-sync hits).
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            bundledLogo
                        case .empty:
                            bundledLogo
                        @unknown default:
                            bundledLogo
                        }
                    }
                }
            } else {
                // No remote URL — Tier 3: Bundled asset
                bundledLogo
            }
        }
        .frame(width: size, height: size)
    }

    // Tier 3/4: Bundled asset (resolvedLogoAssetName falls back to "AppLogo",
    // which is the Mad Thinker neutral mark — not any community's branding).
    private var bundledLogo: some View {
        Image(config.resolvedLogoAssetName)
            .resizable()
            .scaledToFit()
    }
}
