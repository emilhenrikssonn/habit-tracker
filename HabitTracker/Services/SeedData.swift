import Foundation
import SwiftData

enum SeedData {
    /// Makes sure the settings row exists. New installs start with no habits; onboarding adds the first ones.
    static func installIfNeeded(container: ModelContainer) {
        let ctx = ModelContext(container)
        let existing = try? ctx.fetch(FetchDescriptor<AppPrefs>())
        guard existing?.isEmpty ?? true else { return }
        ctx.insert(AppPrefs())
        try? ctx.save()
    }
}
