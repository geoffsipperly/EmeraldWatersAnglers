//
//  CommunityPickerView.swift
//  SkeenaSystem
//
//  Shown when a user belongs to multiple communities and needs to select
//  which one to work in. Each community is displayed as a tappable logo tile.
//  After selection, the app routes to the appropriate landing view based on
//  their role in that community.
//

import SwiftUI

struct CommunityPickerView: View {
    @StateObject private var communityService = CommunityService.shared
    @StateObject private var auth = AuthService.shared
    @State private var showJoinCommunity = false

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                // Logout button — upper right
                HStack {
                    Spacer()
                    Button(action: logoutTapped) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.badge.xmark")
                                .font(.brandTitle3.weight(.semibold))
                            Text("Log out")
                                .font(.brandFootnote.weight(.semibold))
                        }
                        .foregroundColor(.brandTextPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("logoutCapsule")
                }
                .padding(.horizontal, 20)

                // Platform branding
                Image("MadThinkerLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Select Your Community")
                    .font(.brandTitle2.weight(.bold))
                    .foregroundColor(.brandTextPrimary)

                // Community grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(communityService.memberships) { membership in
                        Button {
                            communityService.setDefaultCommunity(id: membership.communityId)
                            communityService.setActiveCommunity(id: membership.communityId)
                        } label: {
                            communityTile(membership: membership)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("communityTile_\(membership.communities.name)")
                    }

                    // Join another community tile
                    Button {
                        showJoinCommunity = true
                    } label: {
                        joinCommunityTile
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("joinCommunityButton")
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 40)
        }
        .sheet(isPresented: $showJoinCommunity) {
            JoinCommunityView()
        }
    }

    // MARK: - Community Tile

    private func communityTile(membership: CommunityMembership) -> some View {
        let isDefault = membership.communityId == communityService.defaultCommunityId

        return VStack(spacing: 10) {
            // Name area — fixed height so role badges align across tiles
            Text(membership.communities.name)
                .font(.brandSubheadline.weight(.semibold))
                .foregroundColor(.brandTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 40, alignment: .bottom)

            Text(membership.role.capitalized)
                .font(.brandCaption2.weight(.medium))
                .foregroundColor(.brandTextOnLight)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.brandTextPrimary.opacity(0.85), in: Capsule())

            if isDefault {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.brandCaption2)
                    Text("Default")
                        .font(.brandCaption2.weight(.medium))
                }
                .foregroundColor(.yellow)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDefault ? Color.brandAccent.opacity(0.12) : Color.brandStrokeSubtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDefault ? Color.brandAccent.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
    }

    // MARK: - Logout

    private func logoutTapped() {
        Task {
            await auth.signOutRemote()
            await MainActor.run {
                AuthStore.shared.clear()
            }
        }
    }

    // MARK: - Join Community Tile

    private var joinCommunityTile: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .font(.brandTitle2)
                .foregroundColor(.brandAccent)

            Text("Join Community")
                .font(.brandSubheadline.weight(.semibold))
                .foregroundColor(.brandAccent)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.brandAccent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6]))
                .background(Color.brandAccent.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        )
    }
}
