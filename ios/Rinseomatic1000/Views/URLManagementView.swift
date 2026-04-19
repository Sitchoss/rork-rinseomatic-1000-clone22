import SwiftUI

struct URLManagementView: View {
    @State private var urlService = LoginURLRotationService.shared

    var body: some View {
        AppURLManagerSection(urlService: urlService)
            .navigationTitle("URL Management")
    }
}
