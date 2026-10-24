import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        Form {
            Section("추천 방식") {
                Picker("가중치", selection: $viewModel.weightsPreset) {
                    ForEach(WeightsPreset.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                status("네이버 검색 (블로그·카페)", connected: viewModel.configuration.hasNaver)
                status("카카오 검색 + 장소 검증", connected: viewModel.configuration.hasKakao)
                status("Apple WeatherKit", connected: viewModel.configuration.weatherKitEnabled)
            } header: {
                Text("데이터 출처")
            } footer: {
                Text("키는 App/Config/Secrets.xcconfig에서 설정합니다. 앱에 포함된 키는 추출될 수 있으므로 출시 전에 프록시 서버로 옮겨야 해요.")
            }
            Section("개발자 콘솔") {
                Link("네이버 개발자센터", destination: URL(string: "https://developers.naver.com/apps")!)
                Link("카카오 developers", destination: URL(string: "https://developers.kakao.com/console/app")!)
            }
            Section {
                LabeledContent("브랜드", value: "Garden")
                LabeledContent("버전", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
            }
        }
        .navigationTitle("설정")
    }

    private func status(_ title: String, connected: Bool) -> some View {
        LabeledContent(title) {
            Label(connected ? "연결됨" : "키 없음", systemImage: connected ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(connected ? Color.gardenGreen : .secondary)
        }
    }
}
