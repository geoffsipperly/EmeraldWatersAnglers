//
//  JoinCommunityView.swift
//  SkeenaSystem
//
//  Allows authenticated users to join an additional community
//  by entering a 6–8 character alphanumeric code.
//  Presented as a compact centered popup over a dimmed background.
//

import SwiftUI

struct JoinCommunityView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var memberNumber: String = ""
    @State private var isBusy = false
    @State private var errorText: String?
    @State private var successText: String?

    private var isCodeValid: Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: #"^[A-Za-z0-9]{6,8}$"#, options: .regularExpression) != nil
    }

    private var isMemberNumberValid: Bool {
        MemberNumber.isValid(MemberNumber.normalize(memberNumber))
    }

    private var canJoin: Bool {
        isCodeValid && isMemberNumberValid && !isBusy
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop — tap to dismiss
            Color.brandScrim.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Compact card
            VStack(spacing: 14) {
                // Title + close
                ZStack {
                    Text("Join Community")
                        .font(.brandHeadline)
                        .foregroundColor(.brandTextPrimary)
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.brandTitle3)
                                .foregroundColor(.brandTextPrimary.opacity(0.5))
                        }
                    }
                }

                // Community code
                TextField("Community Code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .font(.brandSubheadline)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.brandTextPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(.brandTextPrimary)

                if !code.isEmpty && !isCodeValid {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.brandCaption2)
                            .foregroundColor(.brandError)
                        Text("Must be 6–8 alphanumeric characters")
                            .font(.brandCaption2)
                            .foregroundColor(.brandError)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Member number (from invite email)
                TextField("Member Number (e.g. MAD4ZQ7H9)", text: $memberNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .font(.brandSubheadline)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.brandTextPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(.brandTextPrimary)

                if !memberNumber.isEmpty && !isMemberNumberValid {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.brandCaption2)
                            .foregroundColor(.brandError)
                        Text("Enter the 9-char code from your invite email")
                            .font(.brandCaption2)
                            .foregroundColor(.brandError)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Join button
                Button {
                    Task { await joinTapped() }
                } label: {
                    HStack(spacing: 6) {
                        if isBusy { ProgressView().tint(.white) }
                        Text(isBusy ? "Joining…" : "Join")
                            .font(.brandSubheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(canJoin ? Color.brandAccent : Color.brandAccent.opacity(0.35))
                    )
                    .foregroundColor(.brandTextPrimary)
                }
                .disabled(!canJoin)

                if let err = errorText {
                    Text(err)
                        .foregroundColor(.brandError)
                        .font(.brandCaption)
                        .multilineTextAlignment(.center)
                }

                if let success = successText {
                    Text(success)
                        .foregroundColor(.brandSuccess)
                        .font(.brandCaption)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.12))
            )
            .padding(.horizontal, 32)
        }
        .presentationBackground(.clear)
        .preferredColorScheme(.dark)
    }

    private func joinTapped() async {
        errorText = nil
        successText = nil
        isBusy = true

        do {
            let result = try await CommunityService.shared.joinCommunity(
                code: code,
                memberNumber: memberNumber
            )
            successText = "Joined \(result.communityName ?? "community") as \(result.role ?? "member")!"
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }

        isBusy = false
    }
}
