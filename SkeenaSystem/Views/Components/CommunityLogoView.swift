//
//  CommunityLogoView.swift
//  SkeenaSystem
//
//  Displays the community logo with a three-tier fallback:
//  1. Remote URL (AsyncImage) — if config.logoUrl is set
//  2. Bundled asset — Image(config.resolvedLogoAssetName) during load/failure
//  3. Default "AppLogo" — guaranteed to exist in the asset catalog
//
//  No spinner is shown — the bundled asset renders immediately while
//  the remote image loads, so there is no visual flicker.
//

import SwiftUI

struct CommunityLogoView: View {
    let config: CommunityConfig
    var size: CGFloat = 160

    var body: some View {
        Group {
            if let urlString = config.logoUrl, let url = URL(string: urlString) {
                // Tier 1: Remote URL
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        // Tier 2: Bundled asset fallback on remote failure
                        bundledLogo
                    case .empty:
                        // Loading — show bundled asset (no spinner)
                        bundledLogo
                    @unknown default:
                        bundledLogo
                    }
                }
            } else {
                // No remote URL — Tier 2: Bundled asset
                bundledLogo
            }
        }
        .frame(width: size, height: size)
    }

    // Tier 2/3: Bundled asset (resolvedLogoAssetName falls back to "AppLogo")
    private var bundledLogo: some View {
        Image(config.resolvedLogoAssetName)
            .resizable()
            .scaledToFit()
    }
}
