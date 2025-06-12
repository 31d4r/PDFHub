import SwiftUI

struct GridMenuButtonView: View {
    var description: String
    var icon: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundStyle(.mainPrimary)

                Text(description)
                    .fontWeight(.light)
                    .multilineTextAlignment(.center)
                    .padding()
                    .foregroundStyle(.phFontGray)
            }
            .padding()
            .frame(width: 300, height: 300)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        .mainPrimary,
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: [10]
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
