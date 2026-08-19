import SwiftUI

struct FilterSheetView: View {
    @ObservedObject var viewModel: MovieCatalogViewModel
    @ObservedObject private var catalog = GenreCatalog.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Фильтры")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarItems }
        }
    }

    private var form: some View {
        Form {
            sortSection
            genreSection
            yearSection
            ratingSection
            resetButton
        }
    }

    private var sortSection: some View {
        Section("Сортировка") {
            Picker("Сортировка", selection: $viewModel.sort) {
                ForEach(DiscoverSort.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var genreSection: some View {
        Section("Жанр") {
            ForEach(catalog.genres) { genre in
                genreRow(genre)
            }
        }
    }

    private func genreRow(_ genre: Genre) -> some View {
        HStack {
            Text(genre.name)
            Spacer()
            if isGenreSelected(genre) {
                Image(systemName: "checkmark").foregroundStyle(.orange)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleGenre(genre)
        }
    }

    private func isGenreSelected(_ genre: Genre) -> Bool {
        viewModel.selectedGenre?.id == genre.id
    }

    private func toggleGenre(_ genre: Genre) {
        if isGenreSelected(genre) {
            viewModel.selectedGenre = nil
        } else {
            viewModel.selectedGenre = genre
        }
    }

    private var yearSection: some View {
        Section("Год") {
            Picker("Год", selection: $viewModel.year) {
                Text("Любой").tag(Int?.none)
                ForEach(viewModel.years, id: \.self) { y in
                    Text(String(y)).tag(Optional(y))
                }
            }
        }
    }

    private var ratingSection: some View {
        Section("Минимальный рейтинг") {
            VStack(alignment: .leading) {
                Text(ratingLabel)
                    .foregroundStyle(.orange)
                Slider(value: $viewModel.minRating, in: 0...9.5, step: 0.5)
            }
        }
    }

    private var ratingLabel: String {
        String(format: "%.1f★ и выше", viewModel.minRating)
    }

    private var resetButton: some View {
        Button("Сбросить фильтры") {
            Task {
                await viewModel.resetFilters()
                dismiss()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Применить") {
                Task {
                    await viewModel.applyFilters()
                    dismiss()
                }
            }
            .fontWeight(.semibold)
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Отмена") { dismiss() }
        }
    }
}
