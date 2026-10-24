import SwiftUI

@main
struct PicareaApp: App {
    @State private var viewModel = SearchViewModel(configuration: .fromBundle())

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: viewModel)
                .tint(.gardenGreen)
        }
    }
}
