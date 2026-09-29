import ImageIO
import SwiftUI
import LifeBoardDomain

/// The Calendar lens: a month of the person's days, each cell marked with
/// what it holds, and the chosen day opened in place below the grid.
struct JournalCalendarLens<DayCard: View>: View {
    let days: [JournalDayValue]
    let palette: DaypartPalette
    @Binding var month: Date
    @Binding var selectedDayID: UUID?
    @ViewBuilder let dayCard: (JournalDayValue) -> DayCard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let calendar = Calendar.current

    private var marks: [Date: JournalCalendarMarks.Mark] {
        JournalCalendarMarks.marks(for: days, month: month, calendar: calendar)
    }

    private var selectedDay: JournalDayValue? {
        days.first { $0.id == selectedDayID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button {
                        move(by: -1)
                    } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Previous month")
                    .accessibilityIdentifier("journal.calendar.previousMonth")
                    Spacer()
                    VStack(spacing: 2) {
                        Text(month.formatted(.dateTime.month(.wide).year()))
                            .font(.headline)
                            .contentTransition(.numericText())
                        if isCurrentMonth == false {
                            // A way back without stepping month by month.
                            Button("Today") { jumpToToday() }
                                .font(.caption.weight(.semibold))
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("journal.calendar.today")
                        }
                    }
                    Spacer()
                    Button {
                        move(by: 1)
                    } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Next month")
                    .accessibilityIdentifier("journal.calendar.nextMonth")
                    .disabled(isCurrentMonth)
                }
                MonthGrid(month: month, calendar: calendar) { date in
                    cell(for: date)
                }
                .lifeBoardMotion(.cardReflow, value: month)
                // Swipe between months, like a paper calendar. Simultaneous,
                // so a day's tap still lands; the chevrons remain for anyone
                // who cannot swipe.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            guard abs(value.translation.width) > max(60, abs(value.translation.height) * 1.5) else { return }
                            if value.translation.width < 0 {
                                guard isCurrentMonth == false else { return }
                                move(by: 1)
                            } else {
                                move(by: -1)
                            }
                        }
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("journal.calendar.grid")

                if let selectedDay {
                    dayCard(selectedDay)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text(marks.isEmpty
                        ? "No entries in \(month.formatted(.dateTime.month(.wide)))"
                        : "Pick a day")
                        .font(.subheadline)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .accessibilityIdentifier("journal.calendar.hint")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .lifeBoardMotion(.contentInsertion, value: selectedDayID)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func move(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return }
        Haptic.pick.play()
        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
            month = next
            selectedDayID = nil
        }
    }

    private func jumpToToday() {
        Haptic.pick.play()
        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
            month = Date()
            selectedDayID = nil
        }
    }

    private func cell(for date: Date) -> some View {
        let start = calendar.startOfDay(for: date)
        let mark = marks[start]
        let isSelected = mark?.dayID == selectedDayID && selectedDayID != nil
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)
        return Button {
            guard let mark else { return }
            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                selectedDayID = selectedDayID == mark.dayID ? nil : mark.dayID
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(dayNumber)")
                    .font(.callout.weight(mark == nil ? .regular : .semibold))
                    .foregroundStyle(mark == nil ? palette.color(for: .foregroundSecondary) : palette.color(for: .foreground))
                // Each mark has its own shape as well as its own ink, so
                // the cell reads without colour: a dot for words, a diamond
                // for a mood, a square for photos.
                HStack(spacing: 3) {
                    if let mark {
                        if mark.hasText {
                            Circle().fill(palette.color(for: .foreground)).frame(width: 6, height: 6)
                        }
                        if let mood = mark.mood, mood != .none {
                            Rectangle()
                                .fill(Color(SemanticColorTokens.foundationApricotInk))
                                .frame(width: 5, height: 5)
                                .rotationEffect(.degrees(45))
                                .frame(width: 7, height: 7)
                        }
                        if mark.photoCount > 0 {
                            Rectangle()
                                .fill(Color(SemanticColorTokens.foundationSageInk))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .frame(height: 7)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .fill(isSelected ? Color(SemanticColorTokens.foundationSurfaceSelected) : Color.clear)
            )
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        .strokeBorder(Color(SemanticColorTokens.foundationApricotInk), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Not `.disabled`: VoiceOver read empty days as dimmed controls. They
        // stay reachable and say "Nothing written"; the tap simply does nothing.
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(isToday ? "Today, " + (mark?.accessibilityValue ?? "Nothing written") : (mark?.accessibilityValue ?? "Nothing written"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("journal.calendar.day.\(dayNumber)")
    }
}

/// The Gallery lens: every photo across every day, newest first, opening in
/// the existing inspector. Reveals once per cell the first time it appears.
struct JournalMediaGalleryLens: View {
    struct Item: Identifiable {
        let media: JournalMediaValue
        let day: JournalDayValue
        var id: UUID { media.id }
    }

    let days: [JournalDayValue]
    let palette: DaypartPalette

    @State private var inspected: JournalMediaValue?
    @State private var revealed: Set<UUID> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var items: [Item] {
        days.sorted { $0.day > $1.day }.flatMap { day in
            day.media.filter { $0.kind == .photo && $0.payload != nil }.map { Item(media: $0, day: day) }
        }
    }

    var body: some View {
        ScrollView {
            if items.isEmpty {
                StatusSurface(state: .noRecord, title: String(localized: "No photos yet"), message: "")
                    .padding(.top, 40)
                    .padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 4)], spacing: 4) {
                    ForEach(items) { item in
                        if let payload = item.media.payload {
                            Button {
                                inspected = item.media
                            } label: {
                                // A square cell the image fills and is clipped
                                // to: `frame(minWidth:)` before `aspectRatio`
                                // let wide photos spill past their cell.
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay { JournalPhotoThumbnail(id: item.id, payload: payload, pointSide: 208) }
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                                    .lifeboardJournalMediaReveal(progress: revealed.contains(item.id) ? 1 : 0)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Photo from \(item.day.day.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .accessibilityIdentifier("journal.gallery.photo.\(item.id.uuidString)")
                            .onAppear {
                                guard revealed.contains(item.id) == false else { return }
                                if reduceMotion {
                                    revealed.insert(item.id)
                                } else {
                                    withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { _ = revealed.insert(item.id) }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        // A container identifier needs `.contain`, or it is flattened away
        // (and stamped over the cells) in the accessibility tree.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.gallery")
        .sheet(item: $inspected) { media in
            JournalPhotoInspector(media: media)
        }
    }
}

/// A Journal photo, downsampled off the main thread and cached.
///
/// Photo views used to run `UIImage(data:)` on full-size payloads inside the
/// view body, for every cell and every day card, on every render while
/// scrolling. ImageIO decodes straight to the thumbnail size, so the full
/// bitmap is never built, and the cache keeps a row that scrolls back into
/// view from decoding again.
struct JournalPhotoThumbnail: View {
    let id: UUID
    let payload: Data
    /// The longest side the image is drawn at, in points.
    let pointSide: CGFloat
    var contentMode: ContentMode = .fill

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(SemanticColorTokens.foundationSurfaceRecessed)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .task(id: cacheKey) {
            if let cached = JournalThumbnailCache.shared.image(for: cacheKey) {
                image = cached
                return
            }
            let maxPixel = pointSide * displayScale
            let payload = payload
            let key = cacheKey
            let decoded = await Task.detached(priority: .userInitiated) {
                JournalThumbnailCache.downsample(payload, maxPixelSide: maxPixel)
            }.value
            guard Task.isCancelled == false else { return }
            if let decoded { JournalThumbnailCache.shared.insert(decoded, for: key) }
            image = decoded
        }
    }

    /// An edited photo keeps its media id; the byte count moves with the edit.
    private var cacheKey: String {
        "\(id.uuidString)-\(payload.count)-\(Int(pointSide))"
    }
}

final class JournalThumbnailCache: @unchecked Sendable {
    static let shared = JournalThumbnailCache()
    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 240
        return cache
    }()

    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func insert(_ image: UIImage, for key: String) { cache.setObject(image, forKey: key as NSString) }

    static func downsample(_ data: Data, maxPixelSide: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSide))
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// "On this day": one quiet row per match, above today's card.
struct JournalOnThisDayRow: View {
    let matches: [JournalOnThisDay.Match]
    let palette: DaypartPalette
    let onOpen: (JournalDayValue) -> Void

    var body: some View {
        if matches.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(matches) { match in
                    Button {
                        onOpen(match.day)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.color(for: .foreground))
                                Text(match.day.summary ?? String(match.day.displayText.prefix(80)))
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("journal.onThisDay.\(match.day.id.uuidString)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .lifeBoardPaperCard()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("journal.onThisDay")
        }
    }
}
