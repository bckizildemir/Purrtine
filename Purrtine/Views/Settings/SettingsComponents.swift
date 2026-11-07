import SwiftUI

struct SettingsScreen<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        List {
            content()
        }
        .listStyle(.insetGrouped)
    }
}

struct SettingsRowIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(tint)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
    }
}

struct SettingsRowLabel: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let tint: Color
    let detail: String?
    let detailColor: Color
    let showsExternalIndicator: Bool

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color = .accentColor,
        detail: String? = nil,
        detailColor: Color = .secondary,
        showsExternalIndicator: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.detail = detail
        self.detailColor = detailColor
        self.showsExternalIndicator = showsExternalIndicator
    }

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                SettingsRowIcon(systemImage: systemImage, tint: tint)
            }

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .foregroundStyle(.primary)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            if let detail, detail.isEmpty == false {
                Text(detail)
                    .foregroundStyle(detailColor)
                    .multilineTextAlignment(.trailing)
            }

            if showsExternalIndicator {
                Image(systemName: "arrow.up.right.square")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct SettingsInfoBadge: View {
    let title: String
    let tone: NotificationPresentationTone

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch tone {
        case .positive:
            return .green.opacity(0.18)
        case .warning:
            return .orange.opacity(0.18)
        case .critical:
            return .red.opacity(0.18)
        case .neutral:
            return Theme.fillSecondary
        }
    }

    private var foregroundColor: Color {
        switch tone {
        case .positive:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        case .neutral:
            return Theme.labelSecondary
        }
    }
}

struct SettingsInfoCard: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
    let badgeTitle: String?
    let badgeTone: NotificationPresentationTone?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        systemImage: String,
        tint: Color,
        badgeTitle: String? = nil,
        badgeTone: NotificationPresentationTone? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
        self.badgeTitle = badgeTitle
        self.badgeTone = badgeTone
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                SettingsRowIcon(systemImage: systemImage, tint: tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let badgeTitle, let badgeTone {
                        SettingsInfoBadge(title: badgeTitle, tone: badgeTone)
                    }
                }

                Spacer(minLength: 12)
            }

            Text(message)
                .foregroundStyle(.secondary)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.backgroundGroupedSecondary, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct SettingsAppInfoCard: View {
    let appName: String
    let versionText: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cat.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(appName)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text(versionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.backgroundGroupedSecondary, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct SettingsDestinationRow<Destination: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let tint: Color
    let detail: String?
    let accessibilityIdentifier: String?
    @ViewBuilder let destination: () -> Destination

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color = .accentColor,
        detail: String? = nil,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.detail = detail
        self.accessibilityIdentifier = accessibilityIdentifier
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            SettingsRowLabel(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: tint,
                detail: detail
            )
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct SettingsButtonRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let tint: Color
    let role: ButtonRole?
    let accessibilityIdentifier: String?
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color = .accentColor,
        role: ButtonRole? = nil,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.role = role
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            SettingsRowLabel(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: tint,
                detailColor: role == .destructive ? .red : .secondary
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.red : Color.primary)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct SettingsExternalLinkRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let tint: Color
    let url: URL
    let accessibilityIdentifier: String?

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color = .accentColor,
        url: URL,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.url = url
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        Link(destination: url) {
            SettingsRowLabel(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: tint,
                showsExternalIndicator: true
            )
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct SettingsMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let accentColor: Color
    let accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .accessibilityHidden(true)

                    Spacer(minLength: 8)

                    Text(value)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(16)
            .aspectRatio(1.9, contentMode: .fit)
            .background(Theme.backgroundGroupedSecondary, in: RoundedRectangle(cornerRadius: 20))
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

extension View {
    func settingsCardRowStyle() -> some View {
        listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
