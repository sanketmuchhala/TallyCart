import SwiftUI

struct SplashView: View {
    @State private var animate = false
    let title: String

    init(title: String = "TallyCart") {
        self.title = title
    }

    var body: some View {
        ZStack {
            Color("BrandBackground").ignoresSafeArea()
            VStack(spacing: Tokens.Spacing.l) {
                Image("LogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .scaleEffect(animate ? 1.0 : 0.92)
                    .opacity(animate ? 1.0 : 0.7)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color("BrandForeground"))
                ProgressView()
                    .tint(Color("BrandAccent"))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
