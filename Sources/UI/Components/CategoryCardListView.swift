import SwiftUI

struct CategoryCardListView: View {
    let grouped: [(ModelCategory, [ModelQuota])]

    var body: some View {
        ForEach(grouped, id: \.0) { category, models in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: category.icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    Text(category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .tracking(0.5)
                }
                .padding(.horizontal, UISpec.contentHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if category == .unknown {
                    Text("以下模型暂未识别分类，数据仍然有效")
                        .font(.system(size: 9))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        .padding(.horizontal, UISpec.contentHorizontalPadding)
                        .padding(.bottom, 4)
                }

                ForEach(models, id: \.modelName) { model in
                    ModelRowView(model: model, showUnrecognizedTag: category == .unknown)
                    if model.modelName != models.last?.modelName {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .ifPlatformCard()
            .padding(.horizontal, UISpec.contentVerticalPadding)
        }
    }
}
