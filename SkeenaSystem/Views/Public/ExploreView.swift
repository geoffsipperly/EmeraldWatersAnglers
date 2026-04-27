// Bend Fly Shop

import SwiftUI

// MARK: - ExploreView
//
// Explore (a.k.a. "Learn") screen for public-role users. Sections, top → bottom:
//   - Masterclasses — horizontal carousel of bundled videos sourced from
//                     Config/Masterclasses.json (see MasterclassCatalog).
//   - Recommended   — horizontal carousel of up to 5 community-configured links
//                     (CommunityConfig.resolvedCustomUrls). YouTube links derive
//                     a thumbnail from img.youtube.com; non-YouTube links show a
//                     dark placeholder card. All links open in-app via WebView,
//                     which has autoplay enabled for embedded video.

struct ExploreView: View {
  @ObservedObject private var communityService = CommunityService.shared

  @State private var videoLaunch: VideoLaunch?

  private var masterclasses: [Masterclass] {
    MasterclassCatalog.all
  }

  private var customLinks: [CustomURL] {
    communityService.activeCommunityConfig.resolvedCustomUrls
  }

  var body: some View {
    DarkPageTemplate(bottomToolbar: {
      RoleAwareToolbar(activeTab: "explore")
    }) {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if !masterclasses.isEmpty {
            masterclassesSection
          }

          if !customLinks.isEmpty {
            recommendedSection
          }

          Spacer(minLength: 16)
        }
        .padding(.top, 16)
      }
    }
    .navigationTitle("Learn")
    .navigationBarBackButtonHidden(true)
    .navigationDestination(
      isPresented: Binding(
        get: { videoLaunch != nil },
        set: { if !$0 { videoLaunch = nil } }
      )
    ) {
      if let launch = videoLaunch {
        DarkPageTemplate {
          WebView(url: launch.url)
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle(launch.title)
      }
    }
  }

  // MARK: - Masterclasses

  private var masterclassesSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Masterclasses")
        .font(.subheadline.weight(.bold))
        .foregroundColor(.white)
        .padding(.horizontal, 16)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(masterclasses) { item in
            masterclassCard(item)
          }
        }
        .padding(.horizontal, 16)
      }
    }
  }

  private func masterclassCard(_ item: Masterclass) -> some View {
    Button {
      guard let url = URL(string: item.url) else { return }
      videoLaunch = VideoLaunch(url: url, title: item.title)
    } label: {
      ZStack {
        masterclassThumbnail(for: item)
          .frame(width: 220, height: 180)
          .clipped()

        LinearGradient(
          colors: [.clear, .black.opacity(0.7)],
          startPoint: .top,
          endPoint: .bottom
        )

        VStack {
          Spacer()
          HStack(alignment: .bottom) {
            Text(item.title)
              .font(.subheadline.weight(.bold))
              .foregroundColor(.white)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: "play.circle.fill")
              .font(.title)
              .foregroundColor(.white.opacity(0.9))
          }
          .padding(12)
        }
      }
      .frame(width: 220, height: 180)
      .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("masterclassCard_\(item.id)")
  }

  @ViewBuilder
  private func masterclassThumbnail(for item: Masterclass) -> some View {
    if let asset = item.thumbnailAsset, UIImage(named: asset) != nil {
      Image(asset)
        .resizable()
        .scaledToFill()
    } else {
      ZStack {
        placeholderArt
        Text("\(item.id)")
          .font(.system(size: 64, weight: .heavy, design: .rounded))
          .foregroundColor(.white.opacity(0.18))
      }
    }
  }

  // MARK: - Recommended

  private var recommendedSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Recommended")
        .font(.subheadline.weight(.bold))
        .foregroundColor(.white)
        .padding(.horizontal, 16)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(customLinks) { link in
            recommendedCard(link)
          }
        }
        .padding(.horizontal, 16)
      }
    }
  }

  private func recommendedCard(_ link: CustomURL) -> some View {
    Button {
      guard let url = URL(string: link.url) else { return }
      videoLaunch = VideoLaunch(url: url, title: link.name)
    } label: {
      ZStack {
        thumbnail(for: link)
          .frame(width: 220, height: 180)
          .clipped()

        LinearGradient(
          colors: [.clear, .black.opacity(0.7)],
          startPoint: .top,
          endPoint: .bottom
        )

        VStack {
          Spacer()
          HStack(alignment: .bottom) {
            Text(link.name)
              .font(.subheadline.weight(.bold))
              .foregroundColor(.white)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: "play.circle.fill")
              .font(.title)
              .foregroundColor(.white.opacity(0.9))
          }
          .padding(12)
        }
      }
      .frame(width: 220, height: 180)
      .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("learnVideo_\(link.name)")
  }

  @ViewBuilder
  private func thumbnail(for link: CustomURL) -> some View {
    if let thumbURL = YouTubeThumbnail.url(from: link.url) {
      AsyncImage(url: thumbURL) { phase in
        switch phase {
        case .success(let image):
          image.resizable().scaledToFill()
        default:
          placeholderArt
        }
      }
    } else {
      placeholderArt
    }
  }

  private var placeholderArt: some View {
    LinearGradient(
      colors: [Color(white: 0.18), Color(white: 0.28)],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  // MARK: - Helper types

  private struct VideoLaunch: Hashable {
    let url: URL
    let title: String
  }
}

// MARK: - YouTube thumbnail helper

/// Synchronously derives an `img.youtube.com` thumbnail URL from a YouTube
/// watch / embed / shorts / youtu.be URL. Returns nil for any other host so
/// the caller can fall back to placeholder art.
private enum YouTubeThumbnail {
  static func url(from urlString: String) -> URL? {
    guard let id = videoID(from: urlString) else { return nil }
    return URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")
  }

  static func videoID(from urlString: String) -> String? {
    guard let url = URL(string: urlString),
          let host = url.host?.lowercased() else { return nil }

    if host == "youtu.be" {
      let id = String(url.path.dropFirst())
      return id.isEmpty ? nil : id
    }

    guard host == "youtube.com" || host.hasSuffix(".youtube.com") else {
      return nil
    }

    if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let v = comps.queryItems?.first(where: { $0.name == "v" })?.value,
       !v.isEmpty {
      return v
    }

    let parts = url.pathComponents.filter { $0 != "/" }
    if parts.count >= 2, parts[0] == "embed" || parts[0] == "shorts" {
      return parts[1]
    }

    return nil
  }
}
