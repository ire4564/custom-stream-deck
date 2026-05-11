import SwiftUI
import AppKit

/// 컨테이너 안에 비율을 유지하며 fit 으로 그리는 이미지/GIF 표시 뷰.
/// `AnimatedImageView` 가 정적 이미지·GIF 모두 SwiftUI Image + scaledToFit 으로 그리므로
/// 외부에서는 단순히 그것을 컨테이너에 넣어주기만 하면 된다.
struct FilledMediaView: View {
    let url: URL

    var body: some View {
        AnimatedImageView(url: url)
    }
}
