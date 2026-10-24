import GardenCore
import MapKit
import SwiftUI

struct SpotDetailView: View {
    let recommendation: Recommendation
    let now: Date
    @Environment(\.openURL) private var openURL

    private var coordinate: CLLocationCoordinate2D? {
        recommendation.place.map { CLLocationCoordinate2D(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
    }

    var body: some View {
        List {
            if let coordinate {
                Section {
                    Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000))) {
                        Marker(recommendation.name, systemImage: "camera", coordinate: coordinate)
                            .tint(Color.gardenGreen)
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                    Button {
                        openInMaps(coordinate)
                    } label: {
                        Label("Apple 지도에서 길찾기", systemImage: "arrow.triangle.turn.up.right.diamond")
                    }
                }
            } else {
                Section {
                    Label("위치를 확인하지 못한 후보예요 (카카오 로컬 미검증)", systemImage: "mappin.slash")
                        .foregroundStyle(.secondary)
                }
            }

            if let place = recommendation.place {
                Section("장소 정보") {
                    LabeledContent("주소", value: place.address)
                    LabeledContent("분류", value: place.category)
                }
                Section("오늘의 빛") {
                    let sun = SolarCalculator.sunTimes(on: now, at: place.coordinate)
                    LabeledContent("일출", value: sun.sunrise?.shortTime ?? "–")
                    LabeledContent("저녁 골든아워", value: interval(sun.goldenHourEvening))
                    LabeledContent("저녁 블루아워", value: interval(sun.blueHourEvening))
                    LabeledContent("현재 날씨", value: recommendation.sky.koreanName)
                }
            }

            Section("추천 점수") {
                ScoreBar(title: "커뮤니티 인기", value: recommendation.score.community)
                ScoreBar(title: "계절 적합도", value: recommendation.score.season)
                ScoreBar(title: "날씨 적합도", value: recommendation.score.weather)
                ScoreBar(title: "시간대 적합도", value: recommendation.score.time)
                ScoreBar(title: "종합", value: recommendation.score.total, emphasized: true)
            }

            Section {
                ForEach(recommendation.posts) { post in
                    Button {
                        if let url = URL(string: post.url) { openURL(url) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                            if !post.snippet.isEmpty {
                                Text(post.snippet).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            HStack(spacing: 6) {
                                Label(post.source.koreanName, systemImage: post.source.symbolName)
                                if let date = post.publishedAt {
                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("커뮤니티 언급 \(recommendation.posts.count)건")
            } footer: {
                Text("게시글 제목과 요약만 표시해요. 원문과 사진의 저작권은 작성자에게 있어요.")
            }
        }
        .navigationTitle(recommendation.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func interval(_ interval: DateInterval?) -> String {
        guard let interval else { return "–" }
        return "\(interval.start.shortTime) – \(interval.end.shortTime)"
    }

    private func openInMaps(_ coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = recommendation.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
    }
}

struct ScoreBar: View {
    let title: String
    let value: Double
    var emphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(emphasized ? .subheadline.weight(.semibold) : .subheadline)
                Spacer()
                Text("\(Int((value * 100).rounded()))").font(.subheadline.monospacedDigit())
            }
            ProgressView(value: min(max(value, 0), 1))
                .tint(emphasized ? Color.gardenGreen : .secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
