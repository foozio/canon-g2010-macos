import SwiftUI

struct LogConsoleView: View {
    @Binding var logLines: [String]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(logLines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top) {
                            Text("\(index + 1)")
                                .foregroundColor(.gray)
                                .frame(width: 40, alignment: .trailing)
                            Text(line)
                                .foregroundColor(.green)
                        }
                        .id(index)
                    }
                }
                .padding()
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black)
            .cornerRadius(8)
            .frame(height: 300)
            .onChange(of: logLines.count) { old, new in
                if new > 0 {
                    proxy.scrollTo(new - 1, anchor: .bottom)
                }
            }
        }
    }
}
