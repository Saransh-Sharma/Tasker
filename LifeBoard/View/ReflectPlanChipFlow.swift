import SwiftUI

struct ReflectPlanChipFlow<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            AnyLayout(ReflectPlanWrappingHStackLayout(horizontalSpacing: 8, verticalSpacing: 8)) {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        }
    }
}
