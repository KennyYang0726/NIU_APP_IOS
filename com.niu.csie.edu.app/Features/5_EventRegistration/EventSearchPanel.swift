import SwiftUI



enum HourType: String, CaseIterable, Identifiable {
    case all
    case diversity
    case major
    case service

    var id: String { rawValue }
}

extension HourType {
    var localizedTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("Event_search_panel_type_all", comment: "")
        case .diversity:
            return NSLocalizedString("Event_search_panel_type_diversity", comment: "")
        case .major:
            return NSLocalizedString("Event_search_panel_type_major", comment: "")
        case .service:
            return NSLocalizedString("Event_search_panel_type_service", comment: "")
        }
    }
}

struct EventSearchPanel: View {
    @Binding var isExpanded: Bool
    @Binding var searchText: String
    @Binding var selectedType: HourType

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                VStack(alignment: .leading, spacing: isPad ? 16 : 12) {

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField(LocalizedStringKey("Event_search_panel_input_hint"), text: $searchText)
                            .font(.system(size: isPad ? 17 : 15))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: isPad ? 50 : 44)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(LocalizedStringKey("Event_search_panel_event_type"))
                            .font(.system(size: isPad ? 18 : 15, weight: .semibold))

                        HStack(spacing: 8) {
                            ForEach(HourType.allCases) { type in
                                Button {
                                    // 收合虛擬鍵盤
                                    UIApplication.shared.endEditing()
                                    selectedType = type
                                } label: {
                                    Text(type.localizedTitle)
                                        .font(.system(size: isPad ? 16 : 14, weight: .medium))
                                        .foregroundStyle(selectedType == type ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, isPad ? 12 : 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedType == type ? Color.accentColor : Color(.tertiarySystemBackground))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            // 收合虛擬鍵盤
                            UIApplication.shared.endEditing()
                            searchText = ""
                            selectedType = .all
                        } label: {
                            Text(LocalizedStringKey("Event_search_panel_clear_filter"))
                                .font(.system(size: isPad ? 17 : 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isPad ? 14 : 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.tertiarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            // 收合虛擬鍵盤
                            UIApplication.shared.endEditing()
                            searchText = ""
                            selectedType = .all

                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isExpanded = false
                            }
                        } label: {
                            Text(LocalizedStringKey("Event_search_panel_collapse"))
                                .font(.system(size: isPad ? 17 : 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isPad ? 14 : 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.accentColor)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(isPad ? 20 : 16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: isPad ? 20 : 16))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                .padding(.horizontal, isPad ? 24 : 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                // 收合虛擬鍵盤
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.endEditing()
                }
            }
        }
    }
}
