import SwiftUI

// Shows exactly what we know. Nothing else pretends to be here.
struct CandidateView: View {
    let candidate: Candidate
    private var color: Color { Theme.party(candidate.party) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                Text(initials)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 76, height: 76)
                    .background(color, in: RoundedRectangle(cornerRadius: 24))
                    .rotationEffect(.degrees(-6))
                    .shadow(color: color.opacity(0.6), radius: 16, y: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(candidate.name)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        Sticker(candidate.party.label, color: color)
                        if candidate.incumbent { Sticker("Incumbent 👑", color: Theme.yellow) }
                        if candidate.writeIn { Sticker("Write-in ✍️", color: Theme.dim) }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RECEIPTS")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(color)
                Text("Nothing loaded yet. No filings, no clips, no posts.\nWhen it's here, every number links to its source.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.dim)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bg.opacity(0.5), in: RoundedRectangle(cornerRadius: 22))

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.card)
    }

    private var initials: String {
        candidate.name.split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map(String.init)
            .joined()
    }
}
