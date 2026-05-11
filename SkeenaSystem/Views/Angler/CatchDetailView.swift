// Bend Fly Shop
// CatchDetailView.swift
import SwiftUI

struct CatchDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var auth: AuthService

  let report: CatchReportDTO

  @State private var isLoading = true
  @State private var errorText: String?
  @State private var story: CatchStoryDTO?

  var body: some View {
    ZStack {
      Color.brandBackground.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          // Story Title (from API; fall back to river/coordinates while loading)
          Text(story?.title ?? report.displayLocation)
            .font(.brandTitle2.bold())
            .foregroundColor(.brandTextPrimary)
            .padding(.top, 8)

          // Photo (already downloaded URL from the report)
          if let url = report.photoURL {
            AsyncImage(url: url) { phase in
              switch phase {
              case .empty:
                ZStack { Color.brandSurface; ProgressView() }
                  .frame(maxWidth: .infinity, minHeight: 220)
                  .clipShape(RoundedRectangle(cornerRadius: 14))
              case let .success(img):
                img.resizable()
                  .scaledToFill()
                  .frame(maxWidth: .infinity, minHeight: 220)
                  .clipShape(RoundedRectangle(cornerRadius: 14))
              case .failure:
                ZStack {
                  Color.brandSurface
                  Image(systemName: "photo").font(.brandLargeTitle)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14))
              @unknown default:
                Color.brandSurface
                  .frame(maxWidth: .infinity, minHeight: 220)
                  .clipShape(RoundedRectangle(cornerRadius: 14))
              }
            }
          }

          // Catch measurements (displayed when available)
          if report.species != nil || report.length_inches != nil
              || report.girth_inches != nil || report.weight_lbs != nil {
            VStack(alignment: .leading, spacing: 8) {
              if let species = report.species, !species.isEmpty {
                detailRow(label: "Species", value: species)
              }
              if let sex = report.sex, !sex.isEmpty {
                detailRow(label: "Sex", value: sex)
              }
              if let length = report.length_inches {
                detailRow(label: "Length (in)", value: "\(length)")
              }
              if let girth = report.girth_inches {
                detailRow(label: "Girth (in)", value: String(format: "%.1f", girth))
              }
              if let weight = report.weight_lbs {
                detailRow(label: "Weight (lbs)", value: String(format: "%.1f", weight))
              }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.brandStrokeSubtle)
            .cornerRadius(12)
          }

          // Summary / states
          Group {
            if isLoading {
              HStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Generating story…")
                  .foregroundColor(.brandTextPrimary.opacity(0.9))
                  .font(.brandSubheadline)
              }
              .padding(.top, 4)
            } else if let err = errorText {
              Text(err)
                .foregroundColor(.brandError)
                .font(.brandSubheadline)
            } else if let s = story {
              Text(s.summary)
                .foregroundColor(.brandTextPrimary)
                .font(.brandBody)
                .fixedSize(horizontal: false, vertical: true)
            } else {
              Text("No story available.")
                .foregroundColor(.brandTextSecondary)
                .font(.brandSubheadline)
            }
          }
          .padding(.top, 4)

          // Metadata footer (optional, nice touch)
          VStack(alignment: .leading, spacing: 6) {
            Text(Self.fmtDate(report.createdAt))
              .font(.brandFootnote)
              .foregroundColor(.brandTextSecondary)
            HStack(spacing: 6) {
              Image(systemName: "mappin.and.ellipse")
              Text(String(format: "%.4f, %.4f", report.latitude ?? 0, report.longitude ?? 0))
            }
            .font(.brandFootnote)
            .foregroundColor(.brandTextSecondary)

            // Refresh button placed in the metadata area at the bottom
            Button(action: {
              Task { await refreshStory() }
            }) {
              Text("Refresh Story")
                .font(.brandHeadline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandAccent)
                .foregroundColor(.brandTextPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(isLoading)
            }
            .padding(.top, 12)
          }
          .padding(.top, 8)
        }
        .padding(16)
      }
    }
    // Show the navigation bar with a back button and title
    .navigationBarTitle("Detailed Catch Report", displayMode: .inline)
    .navigationBarBackButtonHidden(false)
    .navigationBarHidden(false) // explicitly unhide on this screen
    .task { await loadStory() }
    .preferredColorScheme(.dark)
  }

  // MARK: - Detail Row Helper

  private func detailRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.brandSubheadline)
        .foregroundColor(.brandTextSecondary)
        .frame(width: 70, alignment: .leading)
      Text(value)
        .font(.brandSubheadline)
        .foregroundColor(.brandTextPrimary)
      Spacer()
    }
  }

  // Load (cached if possible; otherwise request and cache)
  private func loadStory() async {
    isLoading = true
    errorText = nil
    do {
      let s = try await CatchStoryService.shared.fetchStoryWithCache(catchId: report.catch_id)
      withAnimation { self.story = s }
    } catch {
      self.errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
    isLoading = false
  }

  // Force-refresh from the server and persist the result
  private func refreshStory() async {
    isLoading = true
    errorText = nil
    do {
      let s = try await CatchStoryService.shared.fetchFreshStory(catchId: report.catch_id)
      withAnimation { self.story = s }
    } catch {
      self.errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
    isLoading = false
  }

  private static func fmtDate(_ iso: String) -> String {
    if let d = DateFormatting.parseISO(iso) { return DateFormatting.mediumDateTime.string(from: d) }
    return iso
  }

  private static func parseISO(_ iso: String) -> Date? {
    DateFormatting.parseISO(iso)
  }
}
