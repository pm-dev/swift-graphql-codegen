import PluginFixtures
import Testing

struct GraphQLCodegenPluginTests {
    @Test
    func buildToolPluginGeneratesCompilableSources() {
        #expect(String(describing: PluginFixture().operationType) == "ValueQuery")
    }
}
