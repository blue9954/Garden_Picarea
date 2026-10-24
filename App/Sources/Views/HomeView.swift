import GardenCore
import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SunTimesCard(sun: viewModel.sunTimes, now: viewModel.now,
                                 season: viewModel.season, regionName: viewModel.regionName)
                }
                Section {
                    ThemeChips(selection: $viewModel.selectedTheme, season: viewModel.season)
                        .listRowInsets(EdgeInsets())
                }
                if !viewModel.warnings.isEmpty, viewModel.phase == .loaded {
                    Section {
                        Label("일부 출처를 불러오지 못했어요", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    } footer: {
                        Text(viewModel.warnings.joined(separator: "\n"))
                    }
                }
                results
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Picarea")
            .searchable(text: $viewModel.query, prompt: "지역이나 테마 (예: 제주 수국)")
            .onSubmit(of: .search) { viewModel.submit() }
            .refreshable { await viewModel.refresh() }
            .navigationDestination(for: Recommendation.self) { SpotDetailView(recommendation: $0, now: viewModel.now) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView(viewModel: viewModel) } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("설정")
                }
            }
            .task { await viewModel.bootstrap() }
        }
    }

    @ViewBuilder
    private var results: some View {
        switch viewModel.phase {
        case .idle:
            EmptyView()
        case .loading:
            Section {
                HStack {
                    Spacer()
                    ProgressView("커뮤니티에서 출사지를 찾는 중…")
                    Spacer()
                }
                .padding(.vertical, 24)
            }
        case .loaded:
            Section("‘\(viewModel.effectiveQuery)’ 추천 출사지") {
                ForEach(Array(viewModel.recommendations.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item) {
                        RecommendationRow(rank: index + 1, recommendation: item)
                    }
                }
            }
        case .empty:
            Section {
                ContentUnavailableView("추천할 출사지를 찾지 못했어요",
                                       systemImage: "camera.metering.unknown",
                                       description: Text("검색어를 더 넓게 바꾸거나 다른 테마를 골라 보세요."))
            }
        case .needsSetup:
            Section {
                ContentUnavailableView {
                    Label("API 키가 필요해요", systemImage: "key")
                } description: {
                    Text("App/Config/Secrets.xcconfig에 네이버 또는 카카오 API 키를 넣고 다시 빌드해 주세요.")
                }
            }
        case .failed(let message):
            Section {
                ContentUnavailableView {
                    Label("검색에 실패했어요", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("다시 시도") { viewModel.submit() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct ThemeChips: View {
    @Binding var selection: Theme?
    let season: Season

    /// 제철 테마를 앞으로.
    private var ordered: [Theme] {
        Theme.allCases.sorted { lhs, rhs in
            let l = lhs.seasons.contains(season), r = rhs.seasons.contains(season)
            return l != r ? l : (Theme.allCases.firstIndex(of: lhs)! < Theme.allCases.firstIndex(of: rhs)!)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ordered, id: \.self) { theme in
                    let isSelected = selection == theme
                    Button {
                        selection = isSelected ? nil : theme
                    } label: {
                        Label(theme.koreanName, systemImage: theme.symbolName)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.gardenGreen : Color(.secondarySystemFill), in: Capsule())
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

struct SunTimesCard: View {
    let sun: SunTimes
    let now: Date
    let season: Season
    let regionName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(regionName ?? "현재 위치") · \(season.koreanName)", systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let countdown = nextGoldenHourText {
                    Text(countdown)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            HStack(spacing: 0) {
                timeCell("일출", sun.sunrise, symbol: "sunrise")
                timeCell("골든아워", sun.goldenHourEvening?.start, symbol: "camera.aperture")
                timeCell("일몰", sun.sunset, symbol: "sunset")
                timeCell("블루아워", sun.blueHourEvening?.start, symbol: "moon.haze")
            }
        }
        .padding(.vertical, 4)
    }

    private var nextGoldenHourText: String? {
        let windows = [sun.goldenHourMorning, sun.goldenHourEvening].compactMap { $0 }
        if windows.contains(where: { $0.contains(now) }) { return "지금 골든아워" }
        guard let next = windows.map(\.start).filter({ $0 > now }).min() else { return nil }
        let minutes = Int(next.timeIntervalSince(now) / 60)
        return minutes >= 60 ? "골든아워까지 \(minutes / 60)시간 \(minutes % 60)분" : "골든아워까지 \(minutes)분"
    }

    private func timeCell(_ title: String, _ date: Date?, symbol: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(Color.gardenGreen)
            Text(date?.shortTime ?? "–").font(.callout.monospacedDigit().weight(.semibold))
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct RecommendationRow: View {
    let rank: Int
    let recommendation: Recommendation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .frame(width: 28, height: 28)
                .background(Color.gardenGreen.opacity(0.15), in: Circle())
                .foregroundStyle(Color.gardenGreen)
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.name).font(.headline)
                if let address = recommendation.place?.address, !address.isEmpty {
                    Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Label("언급 \(recommendation.posts.count)", systemImage: "bubble.left.and.bubble.right")
                    ForEach(recommendation.themes.sorted { $0.rawValue < $1.rawValue }, id: \.self) { theme in
                        Text(theme.koreanName)
                    }
                    if recommendation.sky != .unknown {
                        Image(systemName: recommendation.sky.symbolName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            ScoreBadge(value: recommendation.score.total)
        }
        .padding(.vertical, 2)
    }
}

struct ScoreBadge: View {
    let value: Double
    var body: some View {
        Text("\(Int((value * 100).rounded()))")
            .font(.callout.monospacedDigit().weight(.bold))
            .foregroundStyle(Color.gardenGreen)
            .accessibilityLabel("추천 점수 \(Int((value * 100).rounded()))점")
    }
}

#Preview {
    HomeView(viewModel: SearchViewModel(configuration: .preview, location: FixedLocationProvider()))
}
